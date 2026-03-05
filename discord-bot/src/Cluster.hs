module Cluster (ClusterMessage(..), clusterMessages) where

import Data.Text (Text)
import Data.Time (UTCTime, diffUTCTime, NominalDiffTime)
import Data.List (sortOn)

data ClusterMessage = ClusterMessage
  { cmId         :: Text
  , cmAuthorId   :: Text
  , cmAuthorName :: Text
  , cmTimestamp  :: UTCTime
  , cmContent    :: Text
  } deriving (Eq, Show)

-- | Maximum time gap (seconds) between messages in the same cluster.
maxGapSeconds :: NominalDiffTime
maxGapSeconds = 300  -- 5 minutes

-- | Cluster messages by time proximity and participant continuity,
-- then select the cluster containing the target message ID.
clusterMessages :: Text -> [ClusterMessage] -> [ClusterMessage]
clusterMessages targetId msgs =
  case filter (any (\m -> cmId m == targetId)) clusters of
    (c:_) -> c
    []    -> []
  where
    sorted = sortOn cmTimestamp msgs
    clusters = buildClusters sorted

    buildClusters [] = []
    buildClusters (m:ms) = go m [m] ms
      where
        go _ acc [] = [reverse acc]
        go prev acc (x:xs)
          | isCloseEnough prev x = go x (x:acc) xs
          | otherwise            = reverse acc : go x [x] xs

    isCloseEnough prev curr =
      let gap = abs (diffUTCTime (cmTimestamp curr) (cmTimestamp prev))
      in gap <= maxGapSeconds
         || cmAuthorId curr == cmAuthorId prev
