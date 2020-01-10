--------------------------------------------------
-- Defaults
--------------------------------------------------
local _defaultConfig = {
  profile = {
    minimapButton = {
      hide = false,
      lock = false,
      minimapPos = 0,
    },
    config = {
      isVisible = true,
      layout = "Default",
      linesToShow = 10,
      showQuality = {
        poor = true,
        common = true,
        uncommon = true,
        rare = true,
        epic = true,
        legendary = true,
      },
      ignoreList = {}
    },
    session = {
      isStarted = false,
      timeDiff = 0,
      totalLinesCount = 0,
      lastMoney = 0,
      madeProfit = false,
      lines = {},
      linesInfo = {}
    },
  },
}


function WTFAddon_GetDefaultConfig()
  return _defaultConfig
end
