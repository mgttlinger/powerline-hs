module Segments.Common where

import Data.Time (formatTime, defaultTimeLocale)
import Data.Time.LocalTime (getZonedTime)

import Segments.Base


-- powerline.segments.common.time.date
timeDateSegment :: SegmentHandler
timeDateSegment args _ = do
        let isTime = argLookup args "istime" False
        let fmt = argLookup args "format" "%Y-%m-%d"
        let hlGroup = if   isTime
                      then "time"
                      else "date"

        t <- getZonedTime
        return . return $ Segment hlGroup $ formatTime defaultTimeLocale fmt t

