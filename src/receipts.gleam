import gleam/dynamic
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/io
import gleam/list
import gleam/result

import decode
import envoy

const league_base_url = "https://americas.api.riotgames.com"

const account_path = "/riot/account/v1/accounts/by-riot-id/"

pub type AccountInfo {
  AccountInfo(puuid: String, game_name: String, tag_line: String)
}

fn decode_info2(data: dynamic.Dynamic) -> Result(AccountInfo, json.DecodeError) {
  let decoder = {
    use puuid <- decode.field("puuid", decode.string)
    use game_name <- decode.field("gameName", decode.string)
    use tag_line <- decode.field("tagLine", decode.string)
    decode.success(AccountInfo(puuid:, game_name:, tag_line:))
  }
  json.parse(from: data, using: decoder)
}

fn get_account_info_request(
  api_key: String,
  game_name: String,
  tag_line: String,
) -> request.Request(String) {
  let assert Ok(base_req) = request.to(league_base_url)
  request.prepend_header(base_req, "accept", "application/json")
  |> request.set_query([#("api_key", api_key)])
  |> request.set_method(http.Get)
  |> request.set_path(account_path <> game_name <> "/" <> tag_line)
}

fn send_request(req: request.Request(String)) -> Result(dynamic.Dynamic, String) {
  case httpc.send(req) {
    Ok(response) -> Ok(decode_response(response))
    Error(_) -> Error("Error sending request")
  }
}

fn decode_response(response: response.Response(String)) -> dynamic.Dynamic {
  dynamic.from(response.body)
}

pub fn main() {
  use api_key <- result.try(
    envoy.get("RIOT_API_KEY") |> result.replace_error("Error getting API_KEY"),
  )

  let account_info_request = get_account_info_request(api_key, "koozie", "0000")

  use info <- result.try(send_request(account_info_request))
  echo decode_info2(info)
    |> result.map_error(fn(err) {
      list.fold(err, "", fn(acc, x) {
        acc <> x.expected <> " " <> x.found <> "\n"
      })
    })
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
