module Main where

import Control.Monad
import Data.Aeson
import qualified Data.ByteString.Lazy as BSL
import Data.List (foldl1')
import Data.Map (findWithDefault)
import Data.Text (pack)
import Rainbow (putChunkLn)
import System.Directory (doesFileExist)
import System.Environment.XDG.BaseDir (getUserConfigDir)
import System.FilePath ((</>))

import Aeson_Merge
import CommandArgs
import ConfigSchema(
    ColourConfig(..),
    ColourSchemeConfig(..),
    ExtConfig(..),
    ExtConfigs(..),
    ForBothSides(..),
    MainConfig(..),
    ThemeConfig(..),
    )
import Rendering
import Segments


main :: IO ()
main = parseArgs >>= \args -> do
    cfgDir  <- getUserConfigDir "powerline"
    config  <- loadConfigFile $ cfgDir </> "config.json" :: IO MainConfig
    colours <- loadConfigFile $ cfgDir </> "colors.json" :: IO ColourConfig

    let ExtConfig shellCS shellTheme = shell . ext $ config

    -- Color scheme
    let csNames = (\dir -> cfgDir </> dir </> shellCS ++ ".json") <$> [
                    "colorschemes",
                    "colorschemes/shell"
                ]
    cs <- loadLayeredConfigFiles csNames :: IO ColourSchemeConfig

    -- Themes - more complicated because we need to merge before parsing
    let default_top_theme = string $ findWithDefault (String $ pack "powerline") "default_top_theme" (common config)
    let themeNames = [
                    default_top_theme,
                    "shell" </> "__main__.json",
                    "shell" </> shellTheme ++ ".json"
                 ]
    let themePaths = (cfgDir </>) . ("themes" </>) <$> themeNames
    themesThatExist <- filterM doesFileExist themePaths
    themeCfg <- loadLayeredConfigFiles themesThatExist :: IO ThemeConfig

    -- Generate prompt
    left_prompt  <- generateSegment args `mapM` left (segments themeCfg)
    right_prompt <- generateSegment args `mapM` right (segments themeCfg)

    -- TODO: putChunkLn is slow - see the docs on how to reduce its overhead
    let renderSeg = renderSegment (colors colours) (groups cs)

    putStrLn "Left:"
    putChunkLn `mapM_` (renderSeg <$> concat left_prompt)

    putStrLn "Right:"
    putChunkLn `mapM_` (renderSeg <$> concat right_prompt)

-- Loads a config file, throwing an exception if there was an error message
loadConfigFile :: FromJSON a => FilePath -> IO a
loadConfigFile path = do
    raw <- BSL.readFile path
    return $ fromRight $ eitherDecode raw

-- Loads multiple config files, merges them, then parses them. Merge is right-biased; last file in the list has precedence.
loadLayeredConfigFiles :: FromJSON a => [FilePath] -> IO a
loadLayeredConfigFiles paths = do
    objs <- mapM loadConfigFile paths :: IO [Value]
    let res = foldl1' mergeJson objs

    -- Convert to target type
    return . fromRight . eitherDecode $ encode res

-- Helper function for extracting result
fromRight :: Either String b -> b
fromRight (Left a)  = error a
fromRight (Right b) = b

