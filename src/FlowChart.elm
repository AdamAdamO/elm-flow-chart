module FlowChart exposing (Model, Msg, addNode, init, subscriptions, update, view)

import Browser
import Dict exposing (Dict)
import DraggableTypes exposing (DraggableTypes(..))
import FlowChart.Types exposing (FCCanvas, FCLink, FCNode, FCPort, Vector2)
import Html exposing (Html, div)
import Html.Attributes as A
import Link
import Node
import Random
import Svg exposing (Svg, svg)
import Svg.Attributes
import Utils.CmdExtra as CmdExtra
import Utils.Draggable as Draggable
import Utils.RandomExtra as RandomExtra



-- MODEL


type alias Model =
    { position : Vector2
    , nodes : Dict String FCNode
    , links : Dict String FCLink
    , currentlyDragging : DraggableTypes
    , dragState : Draggable.DragState
    , nodeMap : String -> Html Msg
    }


type Msg
    = DragMsg (Draggable.Msg DraggableTypes)
    | OnDragBy Vector2
    | OnDragStart DraggableTypes Vector2
    | OnDragEnd
    | AddNode FCNode
    | RemoveNode FCNode
    | AddLink FCLink String FCPort String
    | RemoveLink FCLink


init : FCCanvas -> (String -> Html Msg) -> Model
init canvas nodeMap =
    { position = canvas.position
    , nodes = Dict.fromList (List.map (\n -> ( n.id, n )) canvas.nodes)
    , links = Dict.empty
    , currentlyDragging = None
    , dragState = Draggable.init
    , nodeMap = nodeMap
    }


addNode : FCNode -> Cmd Msg
addNode newNode =
    CmdExtra.message (AddNode newNode)



-- SUB


subscriptions : Model -> Sub Msg
subscriptions model =
    Draggable.subscriptions DragMsg model.dragState



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg mod =
    case msg of
        DragMsg dragMsg ->
            Draggable.update dragEvent dragMsg mod

        OnDragStart currentlyDragging startPos ->
            let
                cCmd =
                    case currentlyDragging of
                        DPort nodeId fcPort link ->
                            let
                                newLink =
                                    { id = "", from = startPos, to = startPos }
                            in
                            Random.generate (AddLink newLink nodeId fcPort) (RandomExtra.randomString 6)

                        _ ->
                            Cmd.none
            in
            ( { mod | currentlyDragging = currentlyDragging }, cCmd )

        OnDragBy deltaPos ->
            case mod.currentlyDragging of
                DCanvas ->
                    ( { mod | position = updateVector2 mod.position deltaPos }, Cmd.none )

                DNode node ->
                    let
                        updateNode fcNode =
                            { fcNode | position = updateVector2 fcNode.position deltaPos }
                    in
                    ( { mod | nodes = Dict.update node.id (Maybe.map updateNode) mod.nodes }, Cmd.none )

                DPort nodeId fcPort maybeLink ->
                    case maybeLink of
                        Nothing ->
                            ( mod, Cmd.none )

                        Just k ->
                            let
                                updateLink fcLink =
                                    { fcLink | to = updateVector2 fcLink.to deltaPos }
                            in
                            ( { mod | links = Dict.update k.id (Maybe.map updateLink) mod.links }, Cmd.none )

                None ->
                    ( mod, Cmd.none )

        OnDragEnd ->
            ( { mod | currentlyDragging = None }, Cmd.none )

        AddNode newNode ->
            ( { mod | nodes = Dict.insert newNode.id newNode mod.nodes }, Cmd.none )

        RemoveNode node ->
            ( { mod | nodes = Dict.remove node.id mod.nodes }, Cmd.none )

        AddLink fcLink nodeId fcPort linkId ->
            let
                newLink : FCLink
                newLink =
                    { fcLink | id = linkId }
            in
            ( { mod
                | links = Dict.insert linkId newLink mod.links
                , currentlyDragging = DPort nodeId fcPort (Just newLink)
              }
            , Cmd.none
            )

        RemoveLink fcLink ->
            ( { mod | links = Dict.remove fcLink.id mod.links }, Cmd.none )


view : Model -> List (Html.Attribute Msg) -> Html Msg
view mod canvasStyle =
    div
        ([ A.style "width" "700px"
         , A.style "height" "580px"
         , A.style "overflow" "hidden"
         , A.style "position" "fixed"
         , A.style "cursor" "move"
         , A.style "background-color" "lightgrey"
         , Draggable.enableDragging DCanvas DragMsg
         ]
            ++ canvasStyle
        )
        [ div
            [ A.style "width" "0px"
            , A.style "height" "0px"
            , A.style "position" "absolute"
            , A.style "left" (String.fromFloat mod.position.x ++ "px")
            , A.style "top" (String.fromFloat mod.position.y ++ "px")
            ]
            (List.map
                (\node ->
                    Node.viewNode node DragMsg (mod.nodeMap node.nodeType)
                )
                (Dict.values mod.nodes)
                ++ [ svg
                        [ Svg.Attributes.overflow "visible" ]
                        (List.map Link.viewLink (Dict.values mod.links))
                   ]
            )
        ]



-- HELPER FUNCTIONS


dragEvent : Draggable.Event Msg DraggableTypes
dragEvent =
    { onDragStartListener = \x -> \y -> Just (OnDragStart x y)
    , onDragByListener = OnDragBy >> Just
    , onDragEndListener = Just OnDragEnd
    }


updateVector2 : Vector2 -> Vector2 -> Vector2
updateVector2 oldPos deltaPos =
    { x = oldPos.x + deltaPos.x, y = oldPos.y + deltaPos.y }
