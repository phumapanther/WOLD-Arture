// usage: node tools/preview-anim.js animgen/movement.lua Roll_Forward [--speed 0.4]   |   node tools/preview-anim.js --stop
// Plays one animgen sequence on the character in the RUNNING Play session, without publishing anything.
//
// Why this exists: animgen files build KeyframeSequences into ServerStorage in Edit mode, but a KeyframeSequence
// is not playable until it is either published ("Save to Roblox") or registered at runtime. This runs the
// animgen file inside the live Server datamodel, hands the sequence to KeyframeSequenceProvider for a temporary
// content id, and plays it on the first player's character — so poses can be looked at and re-tuned in seconds
// instead of burning an upload per attempt. Nothing here survives stopping Play.
//
// The animgen file ends in `return`, so it is wrapped in a function: a bare return would end the chunk and the
// player/preview half below would never run.
const fs = require("fs"), path = require("path");
const connect = require("./mcp-client");

const args = process.argv.slice(2);
const positional = args.filter((a) => !a.startsWith("--") && !/^[\d.]+$/.test(a));
const [file, name] = positional;
const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const speed = Number(opt("--speed", "1"));

// `--stop`: end whatever preview is looping on the character, nothing else.
if (args.includes("--stop")) {
  (async () => {
    const c = await connect();
    const code = `
local plr = game:GetService("Players"):GetPlayers()[1]
local humanoid = plr and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
if not animator then return "no character" end
local n = 0
for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
	if t.Priority ~= Enum.AnimationPriority.Core and t.Priority ~= Enum.AnimationPriority.Idle then t:Stop(0.2) n += 1 end
end
return ("stopped %d track(s)"):format(n)`;
    console.log(c.text(await c.tool("execute_luau", { datamodel_type: "Server", code })));
    c.close(); process.exit();
  })().catch((e) => { console.error(e.message); process.exit(1); });
  return;
}

if (!file || !name) { console.error("usage: node tools/preview-anim.js <animgen file> <sequence name> [--speed n] | --stop"); process.exit(1); }

const source = fs.readFileSync(path.join(__dirname, "..", file), "utf8");

const code = `
local build = function()
${source}
end
local summary = build()

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local KSP = game:GetService("KeyframeSequenceProvider")

local seq = ServerStorage.WOLD_Animations:FindFirstChild("${name}")
if not seq then return "no sequence named ${name} (built: " .. tostring(summary) .. ")" end

local plr = Players:GetPlayers()[1]
if not plr or not plr.Character then return "no character in the running session" end
local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
if not animator then return "character has no Animator" end

-- Drop whatever a previous preview left running so poses do not stack on each other.
for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
	if t.Priority ~= Enum.AnimationPriority.Core and t.Priority ~= Enum.AnimationPriority.Idle then t:Stop(0) end
end

local anim = Instance.new("Animation")
anim.AnimationId = KSP:RegisterKeyframeSequence(seq)
local track = animator:LoadAnimation(anim)
track.Priority = seq.Priority
track.Looped = seq.Loop
track:Play(0.1)
track:AdjustSpeed(${speed})

return ("playing %s on %s | %s"):format("${name}", plr.Name, tostring(summary))
`;

(async () => {
  const c = await connect();
  console.log(`preview ${name} from ${file} (${(code.length / 1024).toFixed(0)} KB, speed ${speed})`);
  console.log(c.text(await c.tool("execute_luau", { datamodel_type: "Server", code })));
  c.close(); process.exit();
})().catch((e) => { console.error(e.message); process.exit(1); });
