import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/json
import gleam/result

import envoy

const league_base_url = "https://americas.api.riotgames.com"

const account_path = "/riot/account/v1/accounts/by-riot-id/"

pub type AccountInfo {
  AccountInfo(puuid: String, game_name: String, tag_line: String)
}

fn decode_info2(json_string: String) -> Result(AccountInfo, String) {
  let decoder = {
    use puuid <- decode.field("puuid", decode.string)
    use game_name <- decode.field("gameName", decode.string)
    use tag_line <- decode.field("tagLine", decode.string)
    decode.success(AccountInfo(puuid:, game_name:, tag_line:))
  }
  json.parse(from: json_string, using: decoder)
  |> result.map_error(fn(_) { "Error parsing info" })
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

fn send_request(req: request.Request(String)) -> Result(String, String) {
  let resp = httpc.send(req)
  case resp {
    Ok(r) -> Ok(r.body)
    Error(_) -> Error("Error sending request")
  }
}

pub fn main() {
  use api_key <- result.try(
    envoy.get("RIOT_API_KEY") |> result.replace_error("Error getting API_KEY"),
  )

  let account_info_request = get_account_info_request(api_key, "koozie", "0000")

  use info <- result.try(send_request(account_info_request))
  use decode_info <- result.try(decode_info2(info))

  io.println(decode_info.game_name)
  Ok("exit")
}
