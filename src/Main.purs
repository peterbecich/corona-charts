module Main where

import Prelude

import Affjax as AX
import Affjax.ResponseFormat as ResponseFormat
import Halogen.Apexchart
import Effect.Aff
import Apexcharts (createChart, render)
import Apexcharts.Chart as C
import Apexcharts.Chart.Zoom as Z
import Apexcharts.Common as CC
import Apexcharts.Series as SE
import Apexcharts.Xaxis as X
import Apexcharts.Yaxis as Y
import Corona.JHU
import D3.Scatter
import Data.Argonaut.Core as J
import Data.Bounded
import Data.Date
import Data.DateTime as DT
import Data.Either (Either(..))
import Data.Enum
import Data.HTTP.Method (Method(..))
import Data.Int
import Data.JSDate
import Data.JSDate as JSDate
import Data.Lens
import Data.Lens.Indexed
import Data.Map as M
import Data.Maybe
import Data.Options ((:=))
import Data.Time hiding (adjust)
import Data.Time.Duration
import Data.Tuple
import Data.Unfoldable
import Effect (Effect)
import Effect.Aff (launchAff, launchAff_)
import Effect.Class
import Effect.Class.Console (log)
import Effect.Exception
import Foreign.Object as O
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.VDom.Driver (runUI)

type Line = String
  
-- main :: Effect Unit
-- main = HA.runHalogenAff do
--     dat <- fetchData >>= case _ of
--       Right x -> pure x
--       Left e  -> liftEffect (throwException (error e))
--     body <- HA.awaitBody
--     pure unit
--     -- runUI plotter unit body

-- plotter :: forall q i o m. H.Component HH.HTML q i o m
-- plotter = H.mkComponent
--   { initialState = \_ -> ["Egypt"]
--   -- , eval = H.mkEval (H.defaultEval)
--   , render = \_ -> pure unit
--   }

main :: Effect Unit
main = launchAff_ $ do
  dat <- fetchData >>= case _ of
    Right x -> pure x
    Left e  -> liftEffect (throwException (error e))

  let egyptData :: SeriesData JSDate Number
      egyptData =
        { name: "Egypt"
        , values: map (\d -> { x: d.date, y: toNumber (d.confirmed) }) (lookupData dat "Egypt")
        }

  let toData :: String -> SeriesData JSDate Number
      toData cty =
        { name: cty
        , values: map (\d -> { x: d.date, y: toNumber (d.confirmed) }) (lookupData dat cty)
        }

  log case Count Log of
    Date -> "date"
    Count c -> case c of
      Linear -> "linear"
      Log    -> "log"


  chart <- liftEffect $ mkSvg "#scatterchart"

  liftEffect do
    let sp = { xAxis: { scale: Date, label: "Date"}
             , yAxis: { scale: Count Log, label: "Confirmed" }
             , series: map toData (O.keys dat.counts)
             -- [toData "US", toData "Egypt", toData "Italy"]
             }
    drawData chart sp

  -- delay (Milliseconds (toNumber 5000))
  -- liftEffect do
  --   let sp = { xAxis: { scale: Date, label: "Date"}
  --            , yAxis: { scale: Count Log, label: "Confirmed" }
  --            , series: [toData "Egypt", toData "Italy"]
  --            }
  --   drawData chart sp



-- main :: Effect Unit
-- main = launchAff_ $ do
--   dat <- fetchData >>= case _ of
--     Right x -> pure x
--     Left e  -> liftEffect (throwException (error e))

--   let egyptData :: Array (Array Number)
--       egyptData = case O.lookup "Egypt" dat of
--         Nothing -> []
--         Just d  -> map (\(Tuple x y) -> [JSDate.getTime x, toNumber y]) (M.toUnfoldable d)

--   liftEffect do

--     render $ createChart "#scatteredchart" (
--          SE.series := [
--             (SE.name := "Egypt" <> SE.data' := egyptData)
--          ]
--          <> C.chart := (C.type' := CC.Scatter <> C.height := 350 <> Z.zoom := (Z.enabled := true <> Z.type' := Z.XY))       
--          <> X.xaxis := (X.tickAmount := 10.0 <> X.type' := X.Datetime)
--          <> Y.yaxis := (Y.tickAmount := 10.0)
--       )

foreign import testRec :: {foo :: String} -> String
foreign import logMe :: forall a. a -> Effect Unit
