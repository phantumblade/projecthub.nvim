vim.opt.runtimepath:append(vim.fn.getcwd())
local config = require("projecthub.config")
config.options = vim.tbl_deep_extend("force", config.defaults, {})
local P = require("projecthub.projects")

local home = vim.fn.expand("~")
local ok, ko = 0, 0

local function check(what, got, want)
  if got == want then
    ok = ok + 1
  else
    ko = ko + 1
    print(string.format("  FALLITO  %-44s -> %s  (atteso %s)", what, tostring(got), tostring(want)))
  end
end

print("--- forma canonica del percorso ---")
-- Una barra di troppo non cambia la cartella per il filesystem, ma cambiava la
-- chiave: lo stesso progetto compariva due volte, e la seconda volta come
-- "eliminato" perche' il prefisso /Volumes/ non veniva piu' riconosciuto.
check("doppia barra iniziale",
  P.normalize_path("//Volumes/SSD/Progetti/App"), "/Volumes/SSD/Progetti/App")
check("barre ripetute nel mezzo",
  P.normalize_path("/Volumes/SSD//Progetti///App"), "/Volumes/SSD/Progetti/App")
check("barra finale",
  P.normalize_path("/Volumes/SSD/Progetti/App/"), "/Volumes/SSD/Progetti/App")
check("gia' canonico resta invariato",
  P.normalize_path("/Volumes/SSD/Progetti/App"), "/Volumes/SSD/Progetti/App")
check("tilde espansa", P.normalize_path("~/Personale"), home .. "/Personale")
check("radice non si svuota", P.normalize_path("/"), "/")
check("stringa vuota", P.normalize_path(""), "")

print("--- riconoscimento dell'unita' esterna ---")
-- Il caso che generava la card rossa "PROGETTO ELIMINATO O SPOSTATO" al posto
-- di "ARCHIVIAZIONE ESTERNA SCOLLEGATA".
for _, p in ipairs({ "/Volumes/SSD_2TB/Progetti/App", "//Volumes/SSD_2TB/Progetti/App" }) do
  local v = P.get_volume_info(p)
  check("esterno: " .. p, v.is_external, true)
  check("volume:  " .. p, v.volume_name, "SSD_2TB")
end

-- Il disco di sistema non e' un'unita' rimovibile
local sys = P.get_volume_info("/Volumes/Macintosh HD/Users/x")
check("disco di sistema non e' esterno", sys.is_external, false)
check("percorso normale non e' esterno", P.get_volume_info(home .. "/Progetti").is_external, false)

print(string.format("\nrisultato: %d passati, %d falliti", ok, ko))
vim.cmd(ko == 0 and "qa!" or "cq")
