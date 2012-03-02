{-# LANGUAGE QuasiQuotes, OverloadedStrings #-}
module Main (main) where

import Chess()
import Config
import Control.Arrow
import Data.List
import Game.Input
import Game.Engine
import Game.ResourceLoader
import System.IO (stderr)
import System.Log.Formatter
import System.Log.Handler as H
import System.Log.Handler.Simple
import System.Log.Logger as L
import UI.Colors
import UI.Render
import Util.Defs
import Util.HashString

-- | Initializes all the loggers' states to what was defined in the config file.
configLogger :: IO ()
configLogger = do root <- getRootLogger

                  let formatter' = simpleLogFormatter Config.logFormat

                  consoleOutput <- streamHandler stderr Config.logLevel

                  let log' = foldl' (flip ($)) root
                        [ L.setLevel Config.logLevel
                        , setHandlers $ map (`H.setFormatter` formatter')
                              [ consoleOutput ]
                        ]

                  -- Apply the changes to the global logger.
                  saveGlobalLogger log'

                  let addLogLevel (l, prio) = updateGlobalLogger l $
                                                  L.setLevel prio

                  -- Set up all our custom logger levels.
                  mapM_ addLogLevel Config.customLogLevels

data GameState = GameState { rectPos :: Coord
                           , rectRot :: Double -- rotation of the rectangle, in radians.
                           }

chessBoard :: Loaders -> Renderer
chessBoard l = let board = [ coord2render (x,y) `atIndex` (x,y) | x <- [0..7], y <- [0..7] ]
                in defaultRenderer { children = board, rendDims = (dx*8, dy*8) }
    where
        w, b :: Renderer
        w = textureRenderer l [hashed|"chess-square-w.png"|]
        b = textureRenderer l [hashed|"chess-square-b.png"|]

        idx2pos :: Coord -> Coord
        idx2pos (x, y) = (dx*x, dy*y)

        coord2render :: Coord -> Renderer
        coord2render (x, y) |     evenx &&     eveny = b
                            | not evenx && not eveny = b
                            | otherwise              = w
            where
                evenx = even x
                eveny = even y

        withPosition :: Renderer -> Coord -> Renderer
        withPosition r c = r { pos = Left c }

        atIndex :: Renderer -> Coord -> Renderer
        atIndex r = withPosition r . idx2pos

        (dx, dy) = rendDims w

display :: GameState -> Loaders -> Renderer
display gs ls = let rect = (rectangleRenderer 600 600 red)
                                { pos = Left . (subtract 300 *** subtract 300) $ rectPos gs
                                , children = [ board ]
                                }
                    board = (chessBoard ls)
                                { pos = Right ( HCenterAlign 0
                                              , VCenterAlign 0
                                              )
                                , rotation = rectRot gs
                                }
                 in rect

-- | Solves for the new position of the rectangle, using the mouse as movement.
solveNewPos :: Coord -> InputState -> Coord
solveNewPos _ is = mousePos is

solveNewRot :: Double -> InputState -> Double
solveNewRot r is = r + v * fromIntegral
                        ((fromEnum $ testKeys is [ LeftButton  ])
                       - (fromEnum $ testKeys is [ RightButton ]))
    where
        v = 0.05 -- velocity

-- | We don't do anything... for now.
update :: GameState -> Double -> InputState -> IO (GameState, [ResourceRequest], Loaders -> Renderer)
update gs _ is = let gs' = GameState { rectPos = solveNewPos (rectPos gs) is
                                     , rectRot = solveNewRot (rectRot gs) is
                                     }
                  in return ( gs'
                            , [ Loaded [hashed|"yellow-dot.png"|]
                              , Loaded [hashed|"chess-square-w.png"|]
                              , Loaded [hashed|"chess-square-b.png"|]
                              ]
                            , display gs'
                            )

initState :: GameState
initState = GameState (100, 100) 0

-- Call initialization routines. Register callback function to display
-- graphics. Enter main loop and process events.
main :: IO ()
main = do configLogger
          runGame Config.windowTitle initState update
