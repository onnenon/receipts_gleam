import decode
import gleam/dynamic
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/list
import gleam/result

import envoy

const league_base_url = "https://americas.api.riotgames.com/riot/account/v1/accounts/by-riot-id/"

pub type AccountInfo {
  AccountInfo(puuid: String, game_name: String, tag_line: String)
}

fn decode_info2(
  data: dynamic.Dynamic,
) -> Result(AccountInfo, List(dynamic.DecodeError)) {
  let decoder =
    decode.into({
      use puuid <- decode.parameter
      use game_name <- decode.parameter
      use tag_line <- decode.parameter
      AccountInfo(puuid, game_name, tag_line)
    })
    |> decode.field("puuid", decode.string)
    |> decode.field("gameName", decode.string)
    |> decode.field("tagLine", decode.string)

  decoder |> decode.from(data)
}

fn get_account_info_request(
  api_key: String,
  game_name: String,
  tag_line: String,
) -> request.Request(String) {
  let assert Ok(base_req) =
    request.to(league_base_url <> game_name <> "/" <> tag_line)
  let req = request.prepend_header(base_req, "accept", "application/json")
  request.set_query(req, [#("api_key", api_key)])
}

fn send_request(
  request: request.Request(String),
) -> Result(dynamic.Dynamic, String) {
  case httpc.send(request) {
    Ok(response) -> response.body |> dynamic.from |> Ok
    Error(_) -> Error("Error sending request")
  }
}

pub fn main() {
  use api_key <- result.try(
    envoy.get("API_KEY") |> result.replace_error("Error getting API_KEY"),
  )

  let account_info_request = get_account_info_request(api_key, "koozie", "0000")
  io.println("here")

  use info <- result.try(send_request(account_info_request))
  let res =
    decode_info2(info)
    |> result.map_error(fn(err) {
      list.fold(err, "", fn(acc, x) {
        acc <> x.expected <> " " <> x.found <> "\n"
      })
    })

  io.debug(res)
  // let decode_info = decode_info2(info)
  // case decode_info {
  //   Ok(account_info) -> {
  //     io.println("Account Info:")
  //     io.println(account_info)
  //   }
  //   Error(errors) -> {
  //     io.println("Error decoding account info:")
  //     io.println(errors)
  //   }
  // }
}
