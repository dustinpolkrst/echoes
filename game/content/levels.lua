-- Legend: # solid, ^ spike, = one-way, P start, G goal, t torch, a-d plates, A-D matching doors,
-- M mirror shrine, ~ veil, % crumble stone, c checkpoint.
--
-- Each act lives in its own file under content/acts so two people can build two acts at once without
-- touching the same file. The first level of each file starts that act; an empty file is an act with no
-- levels yet. Level numbers are positions in the combined list.
local ACTS = { 'content.acts.act1', 'content.acts.act2', 'content.acts.act3', 'content.acts.act4', 'content.acts.act5' }

local levels = {}
for act, path in ipairs(ACTS) do
  for k, def in ipairs(require(path)) do
    if k == 1 then def.act = act end
    levels[#levels + 1] = def
  end
end
return levels
