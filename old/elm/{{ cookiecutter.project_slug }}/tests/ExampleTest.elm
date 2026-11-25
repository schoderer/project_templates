module ExampleTest exposing (suite)

import Expect
import Main exposing (Msg(..), init, update)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Main"
        [ test "starts by greeting the world" <|
            \_ ->
                Expect.equal "Hello World!" init.greeting
        , test "counts clicks" <|
            \_ ->
                init
                    |> update Clicked
                    |> update Clicked
                    |> .clicks
                    |> Expect.equal 2
        ]
