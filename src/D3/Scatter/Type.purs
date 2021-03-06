
module D3.Scatter.Type where

import Prelude

import Data.Either
import Data.Enum
import Data.Exists
import Data.Function.Uncurried
import Data.Identity
import Data.Int
import Data.JSDate (JSDate)
import Data.JSDate as JSDate
import Data.Lens
import Data.Lens.Record as LR
import Data.Maybe
import Data.ModifiedJulianDay (Day)
import Data.Newtype
import Data.Point
import Data.Semiring
import Data.Symbol (SProxy(..))
import Data.Tuple
import Effect
import Foreign.Object as O
import Type.DProd
import Type.DSum
import Type.Equality
import Type.Equiv
import Type.GCompare
import Type.Handler
import Web.DOM.Element (Element)

-- | interval, days since
newtype Days = Days Int

unDays :: Days -> Int
unDays (Days n) = n

derive instance eqDays :: Eq Days
derive instance ordDays :: Ord Days
instance showDays :: Show Days where
    show (Days n) = "Days " <> show n

instance daySemiring :: Semiring Days where
    add (Days x) (Days y) = Days (x + y)
    zero = Days zero
    mul (Days x) (Days y) = Days (x * y)
    one = Days one
instance dayRing :: Ring Days where
    sub (Days x) (Days y) = Days (x - y)

newtype Percent  = Percent Number

unPercent :: Percent -> Number
unPercent (Percent n) = n

instance eqPercent :: Eq Percent where
    eq (Percent x) (Percent y) = x == y
instance ordPercent :: Ord Percent where
    compare (Percent x) (Percent y) = compare x y
instance percentSemiring :: Semiring Percent where
    add (Percent x) (Percent y) = Percent (x + y)
    zero = Percent zero
    mul (Percent x) (Percent y) = Percent (x * y)
    one = Percent one
instance percentRing :: Ring Percent where
    sub (Percent x) (Percent y) = Percent (x - y)
instance percentCRing :: CommutativeRing Percent
instance percentERing :: EuclideanRing Percent where
    degree (Percent x) = degree x
    div (Percent x) (Percent y) = Percent (div x y)
    mod (Percent x) (Percent y) = Percent (mod x y)
instance percentShow :: Show Percent where
    -- show (Percent n) = show (n * 100.0) <> "%"
    show (Percent n) = "Percent " <> show n


data SType a =
        SDay     (a ~ Day)
      | SDays    (a ~ Days)
      | SInt     (a ~ Int)
      | SNumber  (a ~ Number)
      | SPercent (a ~ Percent)

sDay :: SType Day
sDay = SDay refl
sDays :: SType Days
sDays = SDays refl
sInt :: SType Int
sInt = SInt refl
sNumber :: SType Number
sNumber = SNumber refl
sPercent :: SType Percent
sPercent = SPercent refl

class STypeable a where
    sType :: SType a
instance stDay :: STypeable Day where
    sType = sDay
instance stDays :: STypeable Days where
    sType = sDays
instance stInt :: STypeable Int where
    sType = sInt
instance stNumber :: STypeable Number where
    sType = sNumber
instance stPercent :: STypeable Percent where
    sType = sPercent

instance decideSType :: Decide SType where
    decide = case _ of
      SDay rX -> case _ of
        SDay rY -> Just (equivFromF rY rX)
        _       -> Nothing
      SDays rX -> case _ of
        SDays rY -> Just (equivFromF rY rX)
        _        -> Nothing
      SInt rX -> case _ of
        SInt rY -> Just (equivFromF rY rX)
        _        -> Nothing
      SNumber rX -> case _ of
        SNumber rY -> Just (equivFromF rY rX)
        _        -> Nothing
      SPercent rX -> case _ of
        SPercent rY -> Just (equivFromF rY rX)
        _        -> Nothing

instance geqSType :: GEq SType where
    geq = decide
instance gordSType :: GOrd SType where
    gcompare x y = case geq x y of
      Just refl -> GEQ refl
      Nothing   -> case compare (sTypeIx x) (sTypeIx y) of
        LT -> GLT
        EQ -> GLT   -- ???
        GT -> GGT

instance eqSType :: Eq (SType a) where
    eq x y = isJust (geq x y)
instance ordSType :: Ord (SType a) where
    compare x y = toOrdering (gcompare x y)


instance showSType :: Show (SType a) where
    show = case _ of
      SDay _ -> "SDay"
      SDays _ -> "SDays"
      SInt _ -> "SInt"
      SNumber _ -> "SNumber"
      SPercent _ -> "SPercent"
instance gshowSType :: GShow SType where
    gshow = show

sTypeIx :: forall a. SType a -> Int
sTypeIx = case _ of
    SDay     _ -> 0
    SDays    _ -> 1
    SInt     _ -> 2
    SNumber  _ -> 3
    SPercent _ -> 4


sTypeShow :: forall a. SType a -> a -> String
sTypeShow = case _ of
    SDay     r -> show <<< equivTo r
    SDays    r -> show <<< equivTo r
    SInt     r -> show <<< equivTo r
    SNumber  r -> show <<< equivTo r
    SPercent r -> show <<< equivTo r

sTypeFormat :: forall a. SType a -> a -> String
sTypeFormat = runFn2 _formatSType handle

sTypeCompare :: forall a. SType a -> a -> a -> Ordering
sTypeCompare = case _ of
    SDay     r -> \x y -> compare (equivTo r x) (equivTo r y)
    SDays    r -> \x y -> compare (equivTo r x) (equivTo r y)
    SInt     r -> \x y -> compare (equivTo r x) (equivTo r y)
    SNumber  r -> \x y -> compare (equivTo r x) (equivTo r y)
    SPercent r -> \x y -> compare (equivTo r x) (equivTo r y)

allSType :: Array (Exists SType)
allSType =
    [ mkExists sDay
    , mkExists sDays
    , mkExists sInt
    , mkExists sNumber
    , mkExists sPercent
    ]

-- | subset of numeric stypes
data NType a =
        -- NDays    (a ~ Days)
        NInt     (a ~ Int)
      | NNumber  (a ~ Number)
      | NPercent (a ~ Percent)

instance showNType :: Show (NType a) where
    show = case _ of
      -- NDays _ -> "NDays"
      NInt _ -> "NInt"
      NNumber _ -> "NNumber"
      NPercent _ -> "NPercent"
instance gshowNType :: GShow NType where
    gshow = show

fromNType :: forall a. NType a -> SType a
fromNType = case _ of
    NInt     r -> SInt r
    -- NDays    r -> SDays r
    NNumber  r -> SNumber r
    NPercent r -> SPercent r

toNType :: forall a. SType a -> Either (a ~ Day || a ~ Days) (NType a)
toNType = case _ of
    SDay     r -> Left (Left r)
    SDays    r -> Left (Right r)
    -- SDays    r -> Right $ NDays r
    SInt     r -> Right $ NInt r
    SNumber  r -> Right $ NNumber r
    SPercent r -> Right $ NPercent r

nTypeNumber :: forall a. NType a -> a -> Number
nTypeNumber = case _ of
    NInt   r -> toNumber <<< equivTo r
    NNumber r -> equivTo r
    NPercent r -> unPercent <<< equivTo r

numberNType :: forall a. NType a -> Number -> a
numberNType = case _ of
    NInt r -> equivFrom r <<< round
    NNumber r -> equivFrom r
    NPercent r -> equivFrom r <<< Percent

nTypeSubtract :: forall a. NType a -> a -> a -> a
nTypeSubtract = case _ of
    NInt     r -> \x y -> equivFrom r (equivTo r x - equivTo r y)
    NNumber  r -> \x y -> equivFrom r (equivTo r x - equivTo r y)
    NPercent r -> \x y -> equivFrom r (equivTo r x - equivTo r y)

-- nDays :: NType Days
-- nDays = NDays refl
nInt :: NType Int
nInt = NInt refl
nNumber :: NType Number
nNumber = NNumber refl
nPercent :: NType Percent
nPercent = NPercent refl

class NTypeable a where
    nType :: NType a
-- instance ntDays :: NTypeable Days where
--     nType = nDays
instance ntInt :: NTypeable Int where
    nType = nInt
instance ntNumber :: NTypeable Number where
    nType = nNumber
instance ntPercent :: NTypeable Percent where
    nType = nPercent

-- numericRing :: forall a. NType a -> (forall r. (Ring a => r) -> r)
-- numericRing = case _ of
--     NInt     refl -> \x -> withEquiv refl x
--     NNumber  refl -> \x -> withEquiv refl x
--     NPercent refl -> \x -> withEquiv refl x

data Axis = XAxis | YAxis | ZAxis | TAxis
derive instance eqAxis :: Eq Axis
derive instance ordAxis :: Ord Axis
instance showAxis :: Show Axis where
    show = case _ of
      XAxis -> "XAxis"
      YAxis -> "YAxis"
      ZAxis -> "ZAxis"
      TAxis -> "TAxis"

axisLens :: forall a. Axis -> Lens' (Record _) a
axisLens = case _ of
    XAxis -> LR.prop (SProxy :: SProxy "x")
    YAxis -> LR.prop (SProxy :: SProxy "y")
    ZAxis -> LR.prop (SProxy :: SProxy "z")
    TAxis -> LR.prop (SProxy :: SProxy "t")

axisLabel :: Axis -> String
axisLabel = case _ of
    XAxis -> "X Axis"
    YAxis -> "Y Axis"
    ZAxis -> "Color Axis"
    TAxis -> "Time Axis"

allAxis :: Array Axis
allAxis = [XAxis, YAxis, ZAxis, TAxis]

type SomeValue = DSum SType Identity

someValue :: forall a. STypeable a => a -> SomeValue
someValue x = sType :=> Identity x

eqSomeValue :: SomeValue -> SomeValue -> Boolean
eqSomeValue dx dy = withDSum dx (\tx (Identity x) ->
      withDSum dy (\ty (Identity y) ->
        case decide tx ty of
          Nothing -> false
          Just r  -> sTypeCompare tx x (equivFrom r y) == EQ
      )
    )


type ModelRes =
    { params :: O.Object SomeValue
    , r2     :: Number
    }

data ModelFit = LinFit
              | ExpFit
              | LogFit
              | DecFit
              | QuadFit

derive instance eqModelFit :: Eq ModelFit
derive instance ordModelFit :: Ord ModelFit

allModelFit :: Array ModelFit
allModelFit = [LinFit, ExpFit, LogFit, DecFit, QuadFit]

modelFitLabel :: ModelFit -> String
modelFitLabel = case _ of
    LinFit -> "Linear"
    ExpFit -> "Exp. Growth"
    LogFit -> "Logistic"
    DecFit -> "Exp. Decay"
    QuadFit -> "Quadratic"

type FitData a b =
    { fit :: ModelFit
    , info :: O.Object ModelRes
    , values :: Array (Point2D a b)
    }

type SeriesData a b c d =
    { name      :: String
    , values    :: Array (Point a b c d)
    , modelfits :: Array (FitData a b)
    }

infixr 1 type Either as ||

data Scale a = Date   (a ~ Day)
             | Linear (a ~ Days || NType a) Boolean         -- ^ to zero or not
             | Log    (NType a)
             | SymLog (NType a)         -- ^ todo: support parameter

instance gshowScale :: GShow Scale where
    gshow = case _ of
      Date _ -> "Date"
      Linear _ b -> "Linear " <> show b
      Log _    -> "Log"
      SymLog _ -> "SymLog"
instance showScale :: Show (Scale a) where
    show = gshow

initialValidScales :: forall a. SType a -> Array (Scale a)
initialValidScales = case _ of
    SDay r -> [Date r]
    SDays r -> [Linear (Left r) false]
    SInt r -> [Linear (Right (NInt r)) false, Log (NInt r)]
    SNumber r -> [Linear (Right (NNumber r)) false, Log (NNumber r)]
    SPercent r -> [Linear (Right (NPercent r)) false, Log (NPercent r)]

defaultScale :: forall a. SType a -> Scale a
defaultScale = case _ of
    SDay  r    -> Date r
    SDays r    -> Linear (Left r) false
    SInt  r    -> Log (NInt  r)  -- maybe log?
    SNumber r  -> Log (NNumber r)
    SPercent r -> Linear (Right (NPercent r)) false

sDate :: Scale Day
sDate = Date refl
sLinear :: forall a. NTypeable a => Boolean -> Scale a
sLinear = Linear (Right nType)
sLog :: forall a. NTypeable a => Scale a
sLog = Log nType
sSymLog :: forall a. NTypeable a => Scale a
sSymLog = SymLog nType

newtype NScale = NScale (DProd NType Scale)

derive instance newtypeNScale :: Newtype NScale _

instance showNScale :: Show NScale where
    show (NScale x) = gshow (runDProd x nInt)

toNScale :: forall a. Scale a -> Either (a ~ Day || a ~ Days) NScale
toNScale = case _ of
    Date   r  -> Left  (Left r)
    Linear dn b -> case dn of
      Left  d -> Left (Right d)
      Right n -> Right (NScale (DProd (flip Linear b <<< Right)))
    Log    n  -> Right (NScale (DProd Log))
    SymLog n  -> Right (NScale (DProd SymLog))

runNScale :: forall a. NScale -> NType a -> Scale a
runNScale (NScale x) = runDProd x

newtype AxisConf a = AC { scale :: Scale a, label :: String }

type ScatterPlot a b c d =
        { axis   :: PointF AxisConf a b c d
        , series :: Array (SeriesData a b c d)
        }

type SomeScatterPlot =
        forall r.
          (forall a b c d. SType a
                  -> SType b
                  -> SType c
                  -> SType d
                  -> ScatterPlot a b c d
                  -> r
          )
          -> r

newtype OnScale a = OnScale
    (forall r.
        { date   :: a ~ Day -> r
        , linear :: (a ~ Days || NType a) -> Boolean -> r
        , log    :: NType a -> r
        , symlog :: NType a -> r
        } -> r
    )

instance handleScale :: Handle (Scale a) (OnScale a) where
    handle   = handle1
    unHandle = unHandle1
instance handle1Scale :: Handle1 Scale OnScale where
    handle1 = case _ of
      Date   refl -> OnScale (\h -> h.date   refl)
      Linear nt b -> OnScale (\h -> h.linear nt b)
      Log    nt   -> OnScale (\h -> h.log    nt  )
      SymLog nt   -> OnScale (\h -> h.symlog nt  )
    unHandle1 (OnScale f) = f
      { date: Date
      , linear: Linear
      , log: Log
      , symlog: SymLog
      }

newtype OnSType a = OnSType (forall r.
      { day     :: a ~ Day    -> r
      , days    :: a ~ Days   -> r
      , int     :: a ~ Int    -> r
      , number  :: a ~ Number -> r
      , percent :: a ~ Percent -> r
      } -> r
    )

instance handleSType :: Handle (SType a) (OnSType a) where
    handle   = handle1
    unHandle = unHandle1
instance handle1SType :: Handle1 SType OnSType where
    handle1 = case _ of
      SDay     refl -> OnSType (\h -> h.day    refl)
      SDays    refl -> OnSType (\h -> h.days   refl)
      SInt     refl -> OnSType (\h -> h.int   refl)
      SNumber  refl -> OnSType (\h -> h.number refl)
      SPercent refl -> OnSType (\h -> h.percent refl)
    unHandle1 (OnSType f) = f
      { day:     SDay
      , days:    SDays
      , int:    SInt
      , number:  SNumber
      , percent: SPercent
      }

newtype OnModelFit = OnModelFit
    (forall r.
        { linFit  :: Unit -> r
        , quadFit :: Unit -> r
        , expFit  :: Unit -> r
        , logFit  :: Unit -> r
        , decFit  :: Unit -> r
        } -> r
    )

instance handleModelFit :: Handle ModelFit OnModelFit where
    handle   = case _ of
      LinFit  -> OnModelFit (\h -> h.linFit  unit)
      ExpFit  -> OnModelFit (\h -> h.expFit  unit)
      LogFit  -> OnModelFit (\h -> h.logFit  unit)
      DecFit  -> OnModelFit (\h -> h.decFit  unit)
      QuadFit -> OnModelFit (\h -> h.quadFit unit)
    unHandle (OnModelFit f) = f
      { linFit:  const LinFit
      , expFit:  const ExpFit
      , logFit:  const LogFit
      , decFit:  const DecFit
      , quadFit: const QuadFit
      }

foreign import _formatSType :: forall a. Fn2 (HandleFunc1 SType OnSType) (SType a) (a -> String)
