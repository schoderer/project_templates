module Main exposing (Model, Msg(..), init, main, update, view)

import Browser
import Html exposing (Html, button, div, h1, text)
import Html.Events exposing (onClick)


main : Program () Model Msg
main =
    Browser.sandbox { init = init, update = update, view = view }


type alias Model =
    { greeting : String
    , clicks : Int
    }


init : Model
init =
    { greeting = "Hello World!"
    , clicks = 0
    }


type Msg
    = Clicked


update : Msg -> Model -> Model
update msg model =
    case msg of
        Clicked ->
            { model | clicks = model.clicks + 1 }


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text model.greeting ]
        , div [] [ text ("Clicked " ++ String.fromInt model.clicks ++ " times") ]
        , button [ onClick Clicked ] [ text "Click me" ]
        ]
