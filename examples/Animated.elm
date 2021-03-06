module Animated exposing (..)

import AnimationFrame
import Color
import Element
import Element.Attributes as Attributes
import Element.Events as Events
import Html exposing (Html)
import Materials
import Math.Vector3 as Vector3 exposing (Vec3, vec3)
import OpenSolid.Axis3d as Axis3d exposing (Axis3d)
import OpenSolid.Camera as Camera exposing (Camera)
import OpenSolid.Direction3d as Direction3d exposing (Direction3d)
import OpenSolid.Point3d as Point3d exposing (Point3d)
import OpenSolid.Scene as Scene
import OpenSolid.Scene.Drawable as Drawable exposing (Drawable)
import OpenSolid.Scene.Light as Light exposing (Light)
import OpenSolid.Scene.Material as Material exposing (Material)
import OpenSolid.Vector3d as Vector3d exposing (Vector3d)
import OpenSolid.Viewpoint as Viewpoint
import PointLight exposing (PointLight(..))
import Shapes
import Style
import Style.Border as Border
import Style.Color as Color
import Style.Font as Font
import Task
import Time exposing (Time)
import WebGL.Texture


translateBy : ( Float, Float ) -> Drawable -> Drawable
translateBy ( x, y ) =
    Drawable.translateBy (Vector3d.fromComponents ( x, y, 0 ))


sphere : Material -> ( Float, Float ) -> Drawable
sphere material offset =
    Shapes.sphere material Point3d.origin 1 |> translateBy offset


box : Material -> ( Float, Float ) -> Drawable
box material offset =
    Shapes.box material 1.5 1.5 1.5 |> translateBy offset


cylinder : Material -> ( Float, Float ) -> Drawable
cylinder material offset =
    Shapes.cylinder material
        (Point3d.fromCoordinates ( 0, 0, -0.75 ))
        (Point3d.fromCoordinates ( 0, 0, 0.75 ))
        1
        |> translateBy offset


type Styles
    = DefaultStyle
    | PanelStyle
    | OuterStyle
    | HeadingStyle


view : Model -> Html Msg
view =
    let
        camera =
            Camera.perspective
                { viewpoint =
                    Viewpoint.lookAt
                        { eyePoint = Point3d.fromCoordinates ( 10, 10, 10 )
                        , focalPoint = Point3d.origin
                        , upDirection = Direction3d.positiveZ
                        }
                , screenWidth = 1024
                , screenHeight = 768
                , verticalFieldOfView = degrees 30
                , nearClipDistance = 0.1
                , farClipDistance = 100
                }

        shapes =
            Drawable.group
                [ sphere Materials.gold ( 3, -3 )
                , cylinder Materials.whitePlastic ( 3, 0 )
                , sphere Materials.copper ( 3, 3 )
                , box Materials.chromium ( 0, -3 )
                , sphere Materials.aluminum ( 0, 0 )
                , cylinder Materials.gold ( 0, 3 )
                , sphere Materials.copper ( -3, -3 )
                , box Materials.blackPlastic ( -3, 0 )
                , sphere Materials.whitePlastic ( -3, 3 )
                ]

        pointLightRadius =
            0.05

        pointLight1Start =
            PointLight.at (Point3d.fromCoordinates ( 1.5, 1.5, 3 ))
                { color = vec3 0 2 10
                , radius = pointLightRadius
                }

        pointLight1RotationAxis =
            Axis3d.z

        pointLight2Start =
            PointLight.at (Point3d.fromCoordinates ( 1.5, -1.5, 0 ))
                { color = vec3 3 0 0
                , radius = pointLightRadius
                }

        pointLight2RotationAxis =
            Axis3d.x |> Axis3d.rotateAround Axis3d.z (degrees 45)

        overheadLightColor =
            vec3 5 5 5

        overheadLight1 =
            PointLight.at (Point3d.fromCoordinates ( 8, 8, 5 ))
                { color = overheadLightColor
                , radius = pointLightRadius
                }

        overheadLight2 =
            PointLight.at (Point3d.fromCoordinates ( 8, -8, 5 ))
                { color = overheadLightColor
                , radius = pointLightRadius
                }

        overheadLight3 =
            PointLight.at (Point3d.fromCoordinates ( -8, 8, 5 ))
                { color = overheadLightColor
                , radius = pointLightRadius
                }

        overheadLight4 =
            PointLight.at (Point3d.fromCoordinates ( -8, -8, 5 ))
                { color = overheadLightColor
                , radius = pointLightRadius
                }

        directionalLight1Color =
            vec3 0 0.1 0.02

        directionalLight2Color =
            vec3 0.3 0.3 0.3

        ambientLightColor =
            vec3 0.01 0.01 0.01

        styleSheet =
            Style.styleSheet
                [ Style.style DefaultStyle []
                , Style.style PanelStyle
                    [ Color.background Color.lightGrey
                    , Border.right 1
                    , Border.solid
                    , Color.border Color.darkGrey
                    ]
                , Style.style OuterStyle []
                , Style.style HeadingStyle [ Font.size 18 ]
                ]
    in
    \model ->
        case model.loadedTexture of
            Nothing ->
                Html.text "Loading texture..."

            Just (Err _) ->
                Html.text "Error loading texture"

            Just (Ok lookupTexture) ->
                let
                    seconds =
                        Time.inSeconds model.time

                    lightDirection1 =
                        Direction3d.with
                            { elevation = degrees -15
                            , azimuth = degrees 180 + seconds * degrees 111
                            }

                    lightDirection2 =
                        Direction3d.with
                            { elevation = degrees -45
                            , azimuth = degrees 270 + seconds * degrees 47
                            }

                    pointLight1 =
                        pointLight1Start
                            |> PointLight.rotateAround pointLight1RotationAxis
                                (seconds * degrees 67)

                    pointLight2 =
                        pointLight2Start
                            |> PointLight.rotateAround pointLight2RotationAxis
                                (seconds * degrees 71)

                    addIf flag item list =
                        if flag model then
                            item :: list
                        else
                            list

                    lights =
                        []
                            |> addIf .ambientEnabled
                                (Light.ambient lookupTexture ambientLightColor)
                            |> addIf .directional1Enabled
                                (Light.directional lightDirection1
                                    directionalLight1Color
                                )
                            |> addIf .directional2Enabled
                                (Light.directional lightDirection2
                                    directionalLight2Color
                                )
                            |> addIf .point1Enabled
                                (PointLight.light pointLight1)
                            |> addIf .point2Enabled
                                (PointLight.light pointLight2)
                            |> addIf .overheadEnabled
                                (PointLight.light overheadLight1)
                            |> addIf .overheadEnabled
                                (PointLight.light overheadLight2)
                            |> addIf .overheadEnabled
                                (PointLight.light overheadLight3)
                            |> addIf .overheadEnabled
                                (PointLight.light overheadLight4)

                    scene =
                        Drawable.group
                            ([ shapes ]
                                |> addIf .point1Enabled
                                    (PointLight.drawable pointLight1)
                                |> addIf .point2Enabled
                                    (PointLight.drawable pointLight2)
                            )

                    renderOptions =
                        [ Scene.devicePixelRatio 2
                        , Scene.gammaCorrection 0.45
                        ]

                    sceneElement =
                        Element.html
                            (Scene.renderWith renderOptions lights camera scene)

                    checkbox value message label =
                        Element.checkbox value
                            DefaultStyle
                            [ Events.onCheck message ]
                            (Element.text label)

                    ambientCheckbox =
                        checkbox model.ambientEnabled
                            SetAmbientEnabled
                            "Ambient"

                    directional1Checkbox =
                        checkbox model.directional1Enabled
                            SetDirectional1Enabled
                            "Green directional"

                    directional2Checkbox =
                        checkbox model.directional2Enabled
                            SetDirectional2Enabled
                            "White directional"

                    point1Checkbox =
                        checkbox model.point1Enabled
                            SetPoint1Enabled
                            "Blue point"

                    point2Checkbox =
                        checkbox model.point2Enabled
                            SetPoint2Enabled
                            "Red point"

                    overheadCheckbox =
                        checkbox model.overheadEnabled
                            SetOverheadEnabled
                            "White overhead"

                    checkboxes =
                        Element.column PanelStyle
                            [ Attributes.spacing 5, Attributes.padding 7.5 ]
                            [ Element.el HeadingStyle [] (Element.text "Lights")
                            , Element.spacer 1
                            , ambientCheckbox
                            , directional1Checkbox
                            , directional2Checkbox
                            , point1Checkbox
                            , point2Checkbox
                            , overheadCheckbox
                            ]

                    layout =
                        Element.row OuterStyle
                            [ Attributes.height (Attributes.percent 100) ]
                            [ checkboxes, sceneElement ]
                in
                Element.viewport styleSheet layout


type alias Model =
    { loadedTexture : Maybe (Result WebGL.Texture.Error Light.AmbientLookupTexture)
    , time : Time
    , ambientEnabled : Bool
    , directional1Enabled : Bool
    , directional2Enabled : Bool
    , point1Enabled : Bool
    , point2Enabled : Bool
    , overheadEnabled : Bool
    }


type Msg
    = LoadComplete (Result WebGL.Texture.Error Light.AmbientLookupTexture)
    | SetAmbientEnabled Bool
    | SetDirectional1Enabled Bool
    | SetDirectional2Enabled Bool
    | SetPoint1Enabled Bool
    | SetPoint2Enabled Bool
    | SetOverheadEnabled Bool
    | Tick Float


init : ( Model, Cmd Msg )
init =
    ( { loadedTexture = Nothing
      , time = 0
      , ambientEnabled = True
      , directional1Enabled = True
      , directional2Enabled = True
      , point1Enabled = True
      , point2Enabled = True
      , overheadEnabled = True
      }
    , Task.attempt LoadComplete (Light.loadAmbientLookupTextureFrom "lookup.png")
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        LoadComplete loadedTexture ->
            ( { model | loadedTexture = Just loadedTexture }, Cmd.none )

        Tick time ->
            ( { model | time = time }, Cmd.none )

        SetAmbientEnabled value ->
            ( { model | ambientEnabled = value }, Cmd.none )

        SetDirectional1Enabled value ->
            ( { model | directional1Enabled = value }, Cmd.none )

        SetDirectional2Enabled value ->
            ( { model | directional2Enabled = value }, Cmd.none )

        SetPoint1Enabled value ->
            ( { model | point1Enabled = value }, Cmd.none )

        SetPoint2Enabled value ->
            ( { model | point2Enabled = value }, Cmd.none )

        SetOverheadEnabled value ->
            ( { model | overheadEnabled = value }, Cmd.none )


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , subscriptions = always (AnimationFrame.times Tick)
        , update = update
        , view = view
        }
