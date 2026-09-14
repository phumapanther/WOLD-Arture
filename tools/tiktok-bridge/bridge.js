#!/usr/bin/env node
// tiktok-bridge — TikTok LIVE -> WOLD Arture.
//
// WHY THIS IS A QUEUE AND NOT A WEBHOOK
//
// A Roblox server cannot receive an inbound HTTP request. There is no listener, no port, no way to hand it
// a URL: HttpService only ever calls OUT. So the usual "POST the event to Roblox" design cannot be built,
// and every version of it that looks like it works is really talking to something else.
//
// What this does instead: it holds the events in a numbered ring buffer and serves them at GET /events.
// The game polls a few times a second with the id it last saw and gets everything after it. That makes the
// whole thing replay-safe by construction -- a dropped poll, a lagging server or a Studio restart costs
// nothing, because the next poll asks for the same cursor again.
//
// A live server on roblox.com cannot reach 127.0.0.1 either. For a published game put a tunnel in front of
// this (cloudflared / ngrok) and point TikTokConfig.Url at the public address, or switch the game over to
// Open Cloud MessagingService and run this with --push (see README).
//
//   node bridge.js --user PHUMAPANTHER
//   node bridge.js --user PHUMAPANTHER --port 8787 --key hunter2
//   node bridge.js --mock                      test the whole chain with no live stream
//   node bridge.js --idle                      queue only: events arrive from POST /mock, nothing invented
//   node bridge.js --user X --dump             print the first raw payload of each kind, to check fields
//   node bridge.js --user X --follow-boss      a follow buys a boss too, not just a subscription
//   node bridge.js --user X --sign-key <key>   an Euler Stream key, if the free signing tier refuses
//
// Only dependency is tiktok-live-connector, and only when actually connecting: --mock runs on stdlib alone.
"use strict";

const http = require("http");

// ---------------------------------------------------------------------------- options
const argv = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = argv.indexOf("--" + name);
  return i >= 0 && argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[i + 1] : fallback;
};
const has = (name) => argv.includes("--" + name);

const CFG = {
  user: flag("user", process.env.TIKTOK_USER || "PHUMAPANTHER").replace(/^@/, ""),
  port: Number(flag("port", process.env.TIKTOK_PORT || 8787)),
  host: flag("host", "127.0.0.1"),
  key: flag("key", process.env.TIKTOK_KEY || ""),
  mock: has("mock"),
  // 10 likes = one monster, the user's number. Held here as well as in the game so a like storm is thinned
  // before it is ever queued.
  likesPerMob: Number(flag("likes", 10)),
  // A like storm can be thousands a minute. Without these two the game would be asked to spawn a monster
  // for every one of them, and a Roblox server dies at a few hundred humanoids.
  maxMobsPerEvent: 5,
  maxMobEventsPerMinute: 12,
  // Gift grades, in coins (diamonds). The user's brackets.
  giftTiers: [
    { min: 100, tier: "Chest_Gold", label: "ใหญ่" },
    { min: 10, tier: "Chest_Silver", label: "กลาง" },
    { min: 0, tier: "Chest_Ironbound", label: "เล็ก" },
  ],
  // Only chat starting with this is forwarded. A live chat is mostly conversation and none of it is ours.
  prefix: flag("prefix", "!"),
  keep: 500, // events kept for replay
  followBoss: has("follow-boss"),
  dump: has("dump"),
  // Optional Euler Stream key. The connector signs its requests through api.eulerstream.com, and the free
  // tier is rate-limited per IP: a long stream, or a second start soon after a first, can be refused. A key
  // from eulerstream.com lifts that. Only needed if connecting starts failing.
  signKey: flag("sign-key", process.env.TIKTOK_SIGN_KEY || ""),
};

const log = (...a) => console.log(new Date().toTimeString().slice(0, 8), ...a);

// ---------------------------------------------------------------------------- the queue
// The ids begin again at 1 every time this program starts, so the game needs a way to notice that the run
// it was reading from is gone. Without it, a bridge restarted mid-live leaves the game holding a cursor
// from the old run -- higher than anything the new one will ever issue -- and it silently receives nothing
// for the rest of the stream. A streamer WILL restart this thing mid-live.
const SESSION = Math.random().toString(36).slice(2, 10);
let nextId = 1;
const queue = [];
function emit(event) {
  event.id = nextId++;
  event.at = Date.now();
  queue.push(event);
  while (queue.length > CFG.keep) queue.shift();
  log("→", JSON.stringify(event));
  if (PUSH) push(event);
  return event;
}

// ---------------------------------------------------------------------------- the leaderboard
// Top 3 is computed HERE rather than read off the event payload. The connector's own isTopGifter is not
// present on every version and not filled in on every event, and the thing the user actually asked for --
// "the top 3 of this live" -- is a running total anyway, which only something that watches the whole
// session can know.
const coinsByUser = new Map(); // uniqueId -> coins this session
const nicknames = new Map(); // uniqueId -> display name, for messages

function credit(uniqueId, nickname, coins) {
  if (!uniqueId) return;
  if (nickname) nicknames.set(uniqueId, nickname);
  if (coins > 0) coinsByUser.set(uniqueId, (coinsByUser.get(uniqueId) || 0) + coins);
}

function topThree() {
  return [...coinsByUser.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 3)
    .map(([user, coins]) => ({ user, name: nicknames.get(user) || user, coins }));
}
const isTop3 = (uniqueId) => topThree().some((t) => t.user === uniqueId);

// ---------------------------------------------------------------------------- like throttle
let likeCarry = 0;
let mobEventsThisMinute = 0;
setInterval(() => { mobEventsThisMinute = 0; }, 60_000).unref();

function onLikes(count, uniqueId, nickname) {
  credit(uniqueId, nickname, 0);
  likeCarry += count;
  const whole = Math.floor(likeCarry / CFG.likesPerMob);
  if (whole < 1) return;
  likeCarry -= whole * CFG.likesPerMob;
  if (mobEventsThisMinute >= CFG.maxMobEventsPerMinute) return; // storm: keep counting, stop spawning
  mobEventsThisMinute += 1;
  emit({ kind: "mob", count: Math.min(whole, CFG.maxMobsPerEvent), by: nickname || uniqueId || "" });
}

// ---------------------------------------------------------------------------- gifts / subs / chat
function onGift(coins, uniqueId, nickname, giftName) {
  credit(uniqueId, nickname, coins);
  const grade = CFG.giftTiers.find((t) => coins >= t.min) || CFG.giftTiers[CFG.giftTiers.length - 1];
  emit({
    kind: "chest", tier: grade.tier, label: grade.label, coins,
    by: nickname || uniqueId || "", gift: giftName || "",
  });
}

function onSub(uniqueId, nickname) {
  credit(uniqueId, nickname, 0);
  emit({ kind: "boss", by: nickname || uniqueId || "ผู้ชม" });
}

function onChat(uniqueId, nickname, text) {
  if (!text || !text.startsWith(CFG.prefix)) return;
  emit({
    kind: "cmd",
    text: text.slice(0, 120),
    by: nickname || uniqueId || "",
    // Resolved at the moment the message arrives, which is the moment the permission should be judged.
    top: isTop3(uniqueId),
  });
}

// ---------------------------------------------------------------------------- TikTok
let connected = false;

function connectTikTok() {
  let lib;
  try {
    lib = require("tiktok-live-connector");
  } catch (err) {
    console.error("ไม่พบ tiktok-live-connector — รัน `npm install` ในโฟลเดอร์นี้ก่อน");
    console.error("(หรือรันด้วย --mock เพื่อทดสอบทั้งสายโดยไม่ต้องต่อไลฟ์จริง)");
    process.exit(1);
  }

  // The package renamed its entry class between majors and may do it again; take whichever is there rather
  // than pinning this file to one release.
  const Ctor = lib.TikTokLiveConnection || lib.WebcastPushConnection || lib.TikTokLiveConnector;
  if (!Ctor) {
    console.error("tiktok-live-connector ตัวนี้ไม่มีคลาสที่รู้จัก (TikTokLiveConnection / WebcastPushConnection)");
    process.exit(1);
  }
  const EV = lib.WebcastEvent || {};

  // The options object is NOT optional in v2, whatever the signature suggests: the constructor reads
  // `options.processInitialData` straight off it, so `new Ctor(user)` throws before it ever tries to
  // connect. Passing {} would be enough -- the two settings below are deliberate.
  //
  //  processInitialData: false   on connecting, TikTok hands over the room's recent history. Replaying it
  //                              would empty ten minutes of likes and gifts into the game at once, which is
  //                              the same avalanche the game's own cursor logic refuses on its side.
  //  enableExtendedGiftInfo      makes the connector fetch the gift table, so a gift's diamond value is
  //                              present on the event rather than having to be guessed from its name.
  const conn = new Ctor(CFG.user, {
    processInitialData: false,
    enableExtendedGiftInfo: true,
    signApiKey: CFG.signKey || undefined,
  });

  // v1 emits plain strings, v2 emits the same strings through an enum. Registering both, deduped, means one
  // file works on either without a version check that would go stale.
  const on = (names, fn) => {
    const seen = new Set();
    for (const n of names) {
      if (typeof n === "string" && !seen.has(n)) { seen.add(n); conn.on(n, fn); }
    }
  };

  const idOf = (d) => d?.uniqueId || d?.user?.uniqueId || d?.userId || "";
  const nameOf = (d) => d?.nickname || d?.user?.nickname || d?.uniqueId || "";

  on([EV.LIKE, "like"], (d) => onLikes(Number(d?.likeCount) || 1, idOf(d), nameOf(d)));

  on([EV.GIFT, "gift"], (d) => {
    // Streakable gifts (giftType 1) fire once per tick while the sender holds the button. Counting those
    // would spawn a chest per frame; the total only exists on the tick where repeatEnd is set.
    const giftType = d?.giftType ?? d?.gift?.gift_type ?? d?.gift?.type;
    const repeatEnd = d?.repeatEnd ?? d?.gift?.repeat_end;
    if (giftType === 1 && !repeatEnd) return;
    const each = Number(d?.diamondCount ?? d?.gift?.diamond_count ?? d?.gift?.diamondCount ?? 0) || 0;
    const times = Number(d?.repeatCount ?? d?.gift?.repeat_count ?? d?.gift?.repeatCount ?? 1) || 1;
    onGift(each * times, idOf(d), nameOf(d), d?.giftName || d?.gift?.name || "");
  });

  // SUBSCRIBE does not exist in connector v2: the event is subNotify, and WebcastEvent.SUBSCRIBE reads
  // undefined -- which is exactly how a sub-boss feature ends up never firing once on a real live while
  // testing perfectly against injected events. Both names are registered so either major works.
  on([EV.SUB_NOTIFY, "subNotify", "subscribe"], (d) => onSub(idOf(d), nameOf(d)));

  // A follow is not a subscription. It is free, it is far more frequent, and whether it should buy a boss
  // is the streamer's call -- so it is off unless asked for.
  if (CFG.followBoss) {
    on([EV.FOLLOW, "follow"], (d) => onSub(idOf(d), nameOf(d)));
  }

  on([EV.CHAT, "chat"], (d) => onChat(idOf(d), nameOf(d), d?.comment ?? d?.content ?? ""));

  // The payload shape is the one thing that cannot be confirmed without a live stream: the connector has
  // renamed these fields between majors and nests some of them under `gift`. With --dump the first event of
  // each kind is printed whole, so the first real live shows the truth instead of a silent zero.
  if (CFG.dump) {
    const seen = new Set();
    for (const name of ["like", "gift", "chat", "subNotify", "follow", "member"]) {
      conn.on(name, (d) => {
        if (seen.has(name)) return;
        seen.add(name);
        log("RAW " + name + " =", JSON.stringify(d, (k, v) => (typeof v === "bigint" ? String(v) : v)).slice(0, 1500));
      });
    }
  }

  on([EV.STREAM_END, "streamEnd"], () => { connected = false; log("⏹ ไลฟ์จบแล้ว"); });
  on([EV.DISCONNECTED, "disconnected"], () => { connected = false; log("⚠ หลุดการเชื่อมต่อ กำลังต่อใหม่"); retry(conn); });

  conn.connect()
    .then(() => { connected = true; log(`✅ ต่อไลฟ์ของ @${CFG.user} แล้ว`); })
    .catch((err) => {
      connected = false;
      log("❌ ต่อไลฟ์ไม่ได้:", err?.message || err);
      log("   " + hintFor(err?.message || String(err)));
      log("   จะลองใหม่เองทุก 15 วิ ไม่ต้องปิดหน้าต่างนี้");
      setTimeout(() => retry(conn), 15_000);
    });

  return conn;
}

// The two failures that account for nearly every one of these, said in words instead of in library-speak.
function hintFor(message) {
  const m = String(message).toLowerCase();
  if (m.includes("room id") || m.includes("not found") || m.includes("offline")) {
    return `@${CFG.user} ยังไม่ได้ไลฟ์อยู่ หรือชื่อช่องผิด — กด "ไปไลฟ์" ใน TikTok ให้ขึ้นสถานะ LIVE จริงก่อน`;
  }
  if (m.includes("sign") || m.includes("rate") || m.includes("429") || m.includes("euler")) {
    return "ตัวเซ็นคำขอ (eulerstream) ปฏิเสธ/ติดลิมิต — รอสักครู่แล้วลองใหม่ หรือขอคีย์ฟรีที่ eulerstream.com แล้วรันด้วย --sign-key <คีย์>";
  }
  return "ถ้าเน็ตปกติและช่องไลฟ์อยู่จริง ลองรันด้วย --dump เพื่อดูรายละเอียด";
}

function retry(conn) {
  if (connected) return;
  conn.connect().then(() => { connected = true; log("✅ ต่อใหม่สำเร็จ"); })
    .catch(() => setTimeout(() => retry(conn), 15_000));
}

// ---------------------------------------------------------------------------- optional Open Cloud push
// For a PUBLISHED game, where polling 127.0.0.1 is not possible. Needs an API key with
// universe-messaging-service:publish on the universe.
const PUSH = has("push") || !!process.env.ROBLOX_API_KEY;
const UNIVERSE = flag("universe", process.env.ROBLOX_UNIVERSE_ID || "");
const APIKEY = process.env.ROBLOX_API_KEY || "";
const TOPIC = flag("topic", "TikTokLive");

async function push(event) {
  if (!UNIVERSE || !APIKEY) return;
  try {
    const res = await fetch(
      `https://apis.roblox.com/messaging-service/v1/universes/${UNIVERSE}/topics/${TOPIC}`,
      {
        method: "POST",
        headers: { "x-api-key": APIKEY, "Content-Type": "application/json" },
        body: JSON.stringify({ message: JSON.stringify(event) }),
      },
    );
    if (!res.ok) log("push failed", res.status, await res.text());
  } catch (err) {
    log("push error", err?.message || err);
  }
}

// ---------------------------------------------------------------------------- HTTP
let polls = 0, lastPollAt = 0, lastAfter = -1;

const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://x");
  const send = (code, body) => {
    const text = JSON.stringify(body);
    res.writeHead(code, { "Content-Type": "application/json; charset=utf-8", "Content-Length": Buffer.byteLength(text) });
    res.end(text);
  };

  if (CFG.key && url.searchParams.get("key") !== CFG.key && req.headers["x-key"] !== CFG.key) {
    return send(403, { ok: false, error: "bad key" });
  }

  if (url.pathname === "/health") {
    return send(200, {
      ok: true, session: SESSION, user: CFG.user, connected, queued: queue.length, cursor: nextId - 1, mock: CFG.mock,
      polls, gameCursor: lastAfter,
      lastPollSecondsAgo: lastPollAt ? Math.round((Date.now() - lastPollAt) / 100) / 10 : null,
    });
  }

  if (url.pathname === "/events") {
    const after = Number(url.searchParams.get("after") || 0);
    // The only sign from here that the game is alive and where its cursor is. Worth its noise: "nothing
    // happened in the game" and "the game never asked" look identical from the outside, and they are the
    // two ends of the chain.
    polls += 1; lastPollAt = Date.now(); lastAfter = after;
    const max = Math.min(Number(url.searchParams.get("max") || 20), 50);
    // A cursor from the future (the bridge restarted and ids began again) would starve the game forever.
    // Treat anything past the end as "start from here" instead.
    const behind = after > nextId - 1 ? nextId - 1 : after;
    const events = queue.filter((e) => e.id > behind).slice(0, max);
    return send(200, {
      ok: true, connected, session: SESSION, head: nextId - 1,
      cursor: events.length ? events[events.length - 1].id : behind,
      top: topThree(),
      events,
    });
  }

  if (url.pathname === "/mock" && req.method === "POST") {
    let body = "";
    req.on("data", (c) => { body += c; if (body.length > 4096) req.destroy(); });
    req.on("end", () => {
      try { send(200, { ok: true, event: emit(JSON.parse(body)) }); }
      catch (err) { send(400, { ok: false, error: String(err) }); }
    });
    return;
  }

  send(404, { ok: false });
});

server.listen(CFG.port, CFG.host, () => {
  // The checklist lives HERE and not in run.bat: cmd.exe mangles Thai in a batch file, and one broken echo
  // line with a bracket in it swallowed the command that starts this program -- silently.
  console.log("=".repeat(64));
  console.log(`  สะพาน TikTok LIVE -> WOLD Arture   ช่อง: @${CFG.user}`);
  console.log("=".repeat(64));
  console.log("  1. บัญชีต้องกด 'ไปไลฟ์' ใน TikTok ให้ขึ้น LIVE จริงแล้ว");
  console.log("  2. ปล่อยหน้าต่างนี้เปิดไว้ทั้งไลฟ์");
  console.log("  3. เปิดเกม - Studio กด F5 หรือเข้าเกมที่ publish");
  console.log("  4. ต้องมีตัวแอดมินยืนอยู่ในเซิร์ฟ ไม่งั้นเกมจะไม่ถามอะไรมาเลย");
  console.log("=".repeat(64));
  log(`ฟังอยู่ที่ http://${CFG.host}:${CFG.port}`);
  log(`  /events?after=<id>   เกมดึงจากตรงนี้`);
  log(`  /health              สถานะ`);
  if (CFG.key) log("  ต้องส่ง ?key=... มาด้วย");
  if (PUSH) log(`  push: universe ${UNIVERSE || "(ไม่ได้ตั้ง)"} topic ${TOPIC}`);
});

// ---------------------------------------------------------------------------- go
if (has("idle")) {
  // Queue and /mock endpoint only: no TikTok connection and no invented events. This is the harness the
  // game is tested against -- events arrive exactly when they are posted, one at a time, which is the only
  // way to tell "the chest event works" from "something spawned a chest".
  log("โหมดว่าง: ไม่ต่อไลฟ์ ไม่ยิงอีเวนต์เอง — ยิงเข้ามาเองที่ POST /mock");
  connected = true;
} else if (CFG.mock) {
  log("โหมดทดสอบ: ไม่ต่อไลฟ์จริง จะยิงอีเวนต์สุ่มให้เอง");
  connected = true;
  const names = ["somchai", "nong_ple", "bank99", "mook", "tiktoker_x"];
  const pick = (a) => a[Math.floor(Math.random() * a.length)];
  setInterval(() => {
    const roll = Math.random();
    const who = pick(names);
    if (roll < 0.45) onLikes(Math.ceil(Math.random() * 12), who, who);
    else if (roll < 0.7) onGift(pick([1, 5, 20, 99, 150, 500]), who, who, "Rose");
    else if (roll < 0.82) onSub(who, who);
    else onChat(who, who, pick(["!มึน", "!นอน", "!ชุบ", "!เต้น", "!emote wave", "!time night", "!weather rain", "สวัสดีครับ"]));
  }, 4000);
} else {
  connectTikTok();
}
