
module Corona.Chart.UI.Op where


import Prelude

import Control.Monad.State.Class as State
import Corona.Chart
import D3.Scatter.Type (SType(..))
import D3.Scatter.Type as D3
import Data.Array as A
import Data.Date as D
import Data.Either
import Data.Enum
import Data.Exists
import Data.Functor.Product
import Data.FunctorWithIndex
import Data.Int
import Data.Int.Parse
import Data.Maybe
import Data.ModifiedJulianDay (Day)
import Data.ModifiedJulianDay as MJD
import Data.Number as N
import Data.Ord
import Data.Symbol (SProxy(..))
import Data.Traversable
import Data.Tuple
import Debug.Trace
import Effect.Class
import Effect.Class.Console
import Halogen as H
import Halogen.ChainPicker as ChainPicker
import Halogen.HTML as HH
import Halogen.HTML.CSS as HC
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Util as HU
import Type.Chain as C
import Type.DProd
import Type.DSum
import Type.Equiv
import Undefined

validPickOps :: forall m a. SType a -> Array (SomePickOp m a)
validPickOps t0 = case t0 of
    SDay  _ -> [
        t0       :=> restrictPickOp t0
      , t0       :=> takePickOp
      , D3.sDays :=> dayNumberPickOp 
      , D3.sDay  :=> pointDatePickOp
      ]
    SDays _ -> [
        t0       :=> restrictPickOp t0
      , t0       :=> takePickOp
      , D3.sDays :=> dayNumberPickOp 
      , D3.sDay  :=> pointDatePickOp
      ]
    SInt  r -> [
        D3.sNumber  :=> windowPickOp (I2N r refl)
      , t0          :=> deltaPickOp (D3.NInt r)
      , D3.sPercent :=> pgrowthPickOp (D3.NInt r)
      , D3.sPercent :=> pmaxPickOp (D3.NInt r)
      , t0          :=> restrictPickOp t0
      , t0          :=> takePickOp
      , D3.sDays    :=> dayNumberPickOp
      , D3.sDay     :=> pointDatePickOp
      ]
    SNumber r -> [
        D3.sNumber  :=> windowPickOp (N2N r refl)
      , t0          :=> deltaPickOp (D3.NNumber r)
      , D3.sPercent :=> pgrowthPickOp (D3.NNumber r)
      , D3.sPercent :=> pmaxPickOp (D3.NNumber r)
      , t0          :=> restrictPickOp t0
      , t0          :=> takePickOp
      , D3.sDays    :=> dayNumberPickOp
      , D3.sDay     :=> pointDatePickOp
      ]
    SPercent r -> [
        D3.sPercent :=> windowPickOp (P2P r refl)
      , t0          :=> deltaPickOp (D3.NPercent r)
      , D3.sPercent :=> pgrowthPickOp (D3.NPercent r)
      , D3.sPercent :=> pmaxPickOp (D3.NPercent r)
      , t0          :=> restrictPickOp t0
      , t0          :=> takePickOp
      , D3.sDays    :=> dayNumberPickOp
      , D3.sDay     :=> pointDatePickOp
      ]

type State =
    { pickOpIx :: Int
    }

newtype SomePickOpQuery a r = SomePQState
  (forall b. SType b -> Operation a b -> Tuple r (Operation a b))
  -- ^ it could possibly change the result type?  nah.  not in this case. we
  -- ignore if result type is different

type ChildSlots a =
        ( pickOp :: H.Slot (SomePickOpQuery a)
                           PickOpOutput
                           Int
        )

data Output = ChangeEvent (Exists SType)

data Action = SetPickOpIx Int
            | TriggerUpdate

data Query a r = QueryOp
  (forall b. SType b -> Operation a b
      -> Tuple r (DSum SType (Operation a)))

component
    :: forall a i m. MonadEffect m
    => SType a
    -> H.Component HH.HTML (Query a) i Output m
component t0 =
    H.mkComponent
      { initialState: \_ -> { pickOpIx: 0 }
      , render: render pos
      , eval: H.mkEval $ H.defaultEval
          { handleAction = handleAction pos
          , handleQuery  = handleQuery
          }
      }
  where
    pos = validPickOps t0

render
    :: forall m a.
       Array (SomePickOp m a)
    -> State
    -> H.ComponentHTML Action (ChildSlots a) m
render pos st = HH.div [HU.classProp "single-op-picker"] [
      HH.select [ HE.onSelectedIndexChange (map SetPickOpIx <<< goodIx) ] $
        flip mapWithIndex pos $ \i dspo -> withDSum dspo (\t (PickOp po) ->
          HH.option [HP.selected (i == st.pickOpIx)]
            [ HH.text po.label ]
        )
    , HH.div [HU.classProp "single-op-options"] $
        maybe [] (A.singleton <<< mkSlot) (pos A.!! st.pickOpIx)
    ]
  where
    goodIx i
      | i < A.length pos = Just i
      | otherwise        = Nothing
    mkSlot :: SomePickOp m a -> H.ComponentHTML Action (ChildSlots a) m
    mkSlot dspo = withDSum dspo (\t (PickOp po) ->
        HH.slot _pickOp st.pickOpIx
          (HU.hoistQuery (\(SomePQState f) -> PQState (f t)) po.component)
          unit
          (const (Just TriggerUpdate))
      )


handleAction
    :: forall a m. MonadEffect m
    => Array (SomePickOp m a)
    -> Action
    -> H.HalogenM State Action (ChildSlots a) Output m Unit
handleAction pos act = do
    oldIx <- H.gets (_.pickOpIx)
    st <- H.get
    case act of
      SetPickOpIx i -> H.put { pickOpIx: i }
      TriggerUpdate -> pure unit
    newIx <- H.gets (_.pickOpIx)

    case pos A.!! newIx of
      Nothing   -> log "hey what gives"
      Just dspo -> withDSum dspo (\t _ ->
        H.raise $ ChangeEvent (mkExists t)
      )

handleQuery
    :: forall a m r. MonadEffect m
    => Query a r
    -> H.HalogenM State Action (ChildSlots a) Output m (Maybe r)
handleQuery = case _ of
    QueryOp f -> do
      st <- H.get
      subSt <- H.query _pickOp st.pickOpIx $
          SomePQState (\t op -> Tuple (t :=> op) op)
      for subSt $ \o -> do
        let Tuple r dso = withDSum o f
        -- this needs to be reworked better: setting op's needs to go to the
        -- right index
        -- withDSum dso (\tNew oNew -> void $
        --    H.query _pickOp st.pickOpIx $
        --       SomePQState (\tOld oOld ->
        --           case decide tOld tNew of
        --             Nothing -> trace "what the" $ const $ Tuple unit oOld
        --             Just r  -> trace "ok huh" $ const $ Tuple unit (equivFromF r oNew)
        --         )
        -- )
        pure r
           
_pickOp :: SProxy "pickOp"
_pickOp = SProxy







data PickOpQuery a b r = PQState (Operation a b -> Tuple r (Operation a b))

data PickOpOutput = PickOpUpdate

type SomePickOp m a = DSum SType (PickOp m a)

newtype PickOp m a b = PickOp
      { label     :: String
      , component :: H.Component HH.HTML (PickOpQuery a b) Unit PickOpOutput m
      }

fakeState
    :: forall s r s m. Applicative m
     => s -> (s -> Tuple r s) -> m (Maybe r)
fakeState x f = pure (Just (fst (f x)))

-- | Delta     (NType a) (a ~ b)       -- ^ dx/dt
deltaPickOp :: forall m a. D3.NType a -> PickOp m a a
deltaPickOp nt = PickOp {
      label: "Daily Change"
    , component: H.mkComponent {
        initialState: \_ -> unit
      , render: \_ -> HH.div [HU.classProp "daily-change"] []
      , eval: H.mkEval $ H.defaultEval {
          handleAction = \_ -> H.raise PickOpUpdate
        , handleQuery  = case _ of
            PQState f -> fakeState (Delta nt refl) f
        }
      }
    }

-- | PGrowth   (NType a) (b ~ Percent)   -- ^ (dx/dt)/x        -- how to handle percentage
pgrowthPickOp :: forall m a. D3.NType a -> PickOp m a D3.Percent
pgrowthPickOp nt = PickOp {
      label: "Percent Growth"
    , component: H.mkComponent {
        initialState: \_ -> unit
      , render: \_ -> HH.div [HU.classProp "percent-growth"] []
      , eval: H.mkEval $ H.defaultEval {
          handleAction = \_ -> H.raise PickOpUpdate
        , handleQuery  = case _ of
            PQState f -> fakeState (PGrowth nt refl) f
        }
      }
    }

-- | Window    (ToFractional a b) Int -- ^ moving average of x over t, window (2n+1)
windowPickOp :: forall m a b. ToFractional a b -> PickOp m a b
windowPickOp tf = PickOp {
      label: "Moving Average"
    , component: H.mkComponent {
        initialState: \_ -> 1
      , render: \st -> HH.div [HU.classProp "moving-average"] [
          HH.span_ [HH.text "Window size (before/after)"]
        , HH.input [
            HP.type_ HP.InputNumber
          , HP.value (show st)
          , HE.onValueInput parseWindow
          ]
        ]
      , eval: H.mkEval $ H.defaultEval {
          handleAction = \st -> do
            State.put st
            H.raise PickOpUpdate
        , handleQuery  = case _ of
            PQState f -> do
              i <- State.get
              let Tuple x new = f (Window tf i)
              case new of
                Window _ j -> H.put j
                _          -> pure unit
              pure (Just x)
        }
      }
    }
  where
    parseWindow = map (abs <<< round) <<< N.fromString

-- | PMax      (NType a) (b ~ Percent)   -- ^ rescale to make max = 1 or -1
pmaxPickOp :: forall m a. D3.NType a -> PickOp m a D3.Percent
pmaxPickOp nt = PickOp {
      label: "Percent of Maximum"
    , component: H.mkComponent {
        initialState: \_ -> unit
      , render: \_ -> HH.div [HU.classProp "percent-of-maximum"] []
      , eval: H.mkEval $ H.defaultEval {
          handleAction = \_ -> H.raise PickOpUpdate
        , handleQuery  = case _ of
            PQState f -> fakeState (PMax nt refl) f
        }
      }
    }

type RestrictState  a =
      { cutoffType :: CutoffType
      , condition  :: Condition a
      }

data RestrictAction a = RASetType CutoffType
                      | RASetCondType (Condition Unit)
                      | RASetLimit a


-- | Restrict  (SType a) (a ~ b) CutoffType (Condition a)    -- ^ restrict before/after condition
restrictPickOp :: forall m a. SType a -> PickOp m a a
restrictPickOp t = PickOp {
      label: "Restrict"
    , component: H.mkComponent {
        initialState: \_ ->
            { cutoffType: After
            , condition: AtLeast $ case t of
                SDay r -> equivFrom r $ MJD.fromDate $
                            D.canonicalDate
                              (toEnumWithDefaults bottom top 2020)
                              D.January
                              (toEnumWithDefaults bottom top 22)
                SDays r -> equivFrom r $ D3.Days 0
                SInt r -> equivFrom r $ 100
                SNumber r -> equivFrom r $ toNumber 100
                SPercent r -> equivFrom r $ D3.Percent 0.2
            }
      , render: \st -> HH.div [HU.classProp "restrict"] [
          HH.span_ [HH.text "Keep points..."]
        , HH.select [ HU.classProp "cutoff-list"
                    , HE.onSelectedIndexChange (map RASetType <<< (cutoffList A.!! _))
                    ] $
            cutoffList <#> \c ->
              let isSelected = c == st.cutoffType
              in  HH.option [HP.selected isSelected] [HH.text (showCutoff c)]
        , HH.span_ [HH.text "...being..."]
        , HH.select [ HU.classProp "condition-list"
                    , HE.onSelectedIndexChange (map RASetCondType <<< (condList A.!! _))
                    ] $
            condList <#> \c ->
              let isSelected = c == void st.condition
              in  HH.option [HP.selected isSelected] [HH.text (showCond c)]
        , HH.div [HU.classProp "cond-num-picker"] [
            HH.input [
              HP.type_ inputType
            , HP.value (inputShow (conditionValue st.condition))
            , HE.onValueInput (map RASetLimit <<< inputParse)
            ]
          ]
        ]
      , eval: H.mkEval $ H.defaultEval {
          handleAction = \act -> do
            H.modify_ $ \st ->
              case act of
                RASetType co -> st { cutoffType = co }
                RASetCondType cu ->
                  st { condition = conditionValue st.condition <$ cu }
                RASetLimit v ->
                  st { condition = v <$ st.condition }
            H.raise PickOpUpdate
        , handleQuery  = case _ of
            PQState f -> do
              st <- State.get
              let Tuple x new = f (Restrict t refl st.cutoffType st.condition)
              case new of
                Restrict _ _ ct cond -> H.put { cutoffType: ct, condition: cond }
                _                    -> pure unit
              pure (Just x)
        }
      }
    }
  where
    { inputType, inputParse, inputShow } = inputField t
    showCutoff = case _ of
      After  -> "after"
      Before -> "before"
    showCond = case _ of
      AtLeast _ -> "at least"
      AtMost  _ -> "at most"

type TakeState  a =
      { cutoffType :: CutoffType
      , amount     :: Int
      }

data TakeAction a = TASetType CutoffType
                  | TASetAmount Int

-- | Take      (a ~ b) Int CutoffType    -- ^ take n
takePickOp :: forall m a. PickOp m a a
takePickOp = PickOp {
      label: "Take Amount"
    , component: H.mkComponent {
        initialState: \_ ->
            { cutoffType: Before
            , amount: 30
            }
      , render: \st -> HH.div [HU.classProp "take-amount"] [
          HH.span_ [HH.text "Keep only the..."]
        , HH.select [ HU.classProp "cutoff-list"
                    , HE.onSelectedIndexChange (map TASetType <<< (cutoffList A.!! _))
                    ] $
            cutoffList <#> \c ->
              let isSelected = c == st.cutoffType
              in  HH.option [HP.selected isSelected] [HH.text (showCutoff c)]
        , HH.div [HU.classProp "cond-num-picker"] [
            HH.input [
              HP.type_ HP.InputNumber
            , HP.value (show st.amount)
            , HE.onValueInput (map TASetAmount <<< parseAmount)
            ]
          ]
        , HH.span_ [HH.text "...points"]
        ]
      , eval: H.mkEval $ H.defaultEval {
          handleAction = \act -> do
            H.modify_ $
              case act of
                TASetType co -> _ { cutoffType = co }
                TASetAmount v -> _ { amount = v }
            H.raise PickOpUpdate
        , handleQuery  = case _ of
            PQState f -> do
              st <- State.get
              let Tuple x new = f (Take refl st.amount st.cutoffType)
              case new of
                Take _ amt ct -> H.put { cutoffType: ct, amount: amt }
                _             -> pure unit
              pure (Just x)
        }
      }
    }
  where
    parseAmount = map round <<< N.fromString
    showCutoff = case _ of
      After  -> "first"
      Before -> "last"

-- | DayNumber (b ~ Days) CutoffType     -- ^ day number
dayNumberPickOp :: forall m a b. PickOp m a D3.Days
dayNumberPickOp = PickOp {
      label: "Day Count"
    , component: H.mkComponent {
        initialState: \_ -> After
      , render: \st -> HH.div [HU.classProp "day-count"] [
          HH.span_ [HH.text "Days since/until..."]
        , HH.select [HU.classProp "cutoff-list", HE.onSelectedIndexChange (cutoffList A.!! _)] $
            cutoffList <#> \c ->
              let isSelected = c == st
              in  HH.option [HP.selected isSelected] [HH.text (showCutoff c)]
        ]
      , eval: H.mkEval $ H.defaultEval {
          handleAction = \st -> do
            State.put st
            H.raise PickOpUpdate
        , handleQuery  = case _ of
            PQState f -> do
              c <- State.get
              let Tuple x new = f (DayNumber refl c)
              case new of
                DayNumber _ d -> H.put d
                _             -> pure unit
              pure (Just x)
        }
      }
    }
  where
    showCutoff = case _ of
      After  -> "first day"
      Before -> "last day"

-- | PointDate (b ~ Day)     -- ^ day associated with point
pointDatePickOp :: forall m a. PickOp m a Day
pointDatePickOp = PickOp {
      label: "Date Observed"
    , component: H.mkComponent {
        initialState: \_ -> unit
      , render: \_ -> HH.div [HU.classProp "date-observed"] []
      , eval: H.mkEval $ H.defaultEval {
          handleAction = \_ -> H.raise PickOpUpdate
        , handleQuery  = case _ of
            PQState f -> fakeState (PointDate refl) f
        }
      }
    }


condList :: Array (Condition Unit)
condList = [AtLeast unit, AtMost unit]

cutoffList :: Array CutoffType
cutoffList = [After, Before]

type InputField a =
    { inputType  :: HP.InputType
    , inputParse :: String -> Maybe a
    , inputShow  :: a -> String
    }

inputField :: forall a. SType a -> InputField a
inputField t =
    { inputType: case t of
        SDay _ -> HP.InputDate
        _         -> HP.InputNumber
    , inputParse: case t of
        SDay r -> equivFromF r <<< MJD.fromISO8601
        SDays r -> map (equivFrom r <<< D3.Days <<< round) <<< N.fromString
        SInt    r -> map (equivFrom r <<< round) <<< N.fromString
        SNumber r -> map (equivFrom r) <<< N.fromString
        SPercent r -> map (equivFrom r <<< D3.Percent <<< (_ / toNumber 100))
                     <<< N.fromString
    , inputShow: case t of
        SDay r -> MJD.toISO8601 <<< equivTo r
        SDays r -> show <<< D3.unDays <<< equivTo r
        SInt r -> show <<< equivTo r
        SNumber r -> showPrecision <<< equivTo r
        SPercent r -> showPrecision <<< (_ * toNumber 100) <<< D3.unPercent <<< equivTo r
    }
  where
    showPrecision x = if toNumber (round x) == x then show (round x) else show x
