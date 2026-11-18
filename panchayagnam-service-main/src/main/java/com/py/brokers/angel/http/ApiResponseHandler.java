package com.py.brokers.angel.http;
import static com.py.brokers.angel.client.Constants.APIKEY_EXCEPTION_MESSAGE;
import static com.py.brokers.angel.client.Constants.TOKEN_EXCEPTION_MESSAGE;
import com.py.brokers.angel.exception.ApiKeyException;
import com.py.brokers.angel.exception.DataException;
import com.py.brokers.angel.exception.GeneralException;
import com.py.brokers.angel.exception.InputException;
import com.py.brokers.angel.exception.NetworkException;
import com.py.brokers.angel.exception.OrderException;
import com.py.brokers.angel.exception.PermissionException;
import com.py.brokers.angel.exception.SmartAPIException;
import com.py.brokers.angel.exception.TokenException;
import com.py.brokers.angel.dto.SearchScripResponseDTO;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.util.List;
import okhttp3.Response;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Response handler for handling all the responses.
 */
public class ApiResponseHandler {

	private static final Logger log = LoggerFactory.getLogger(ApiResponseHandler.class);

	public JSONObject handle(Response response, String body) throws IOException, SmartAPIException, JSONException {
		String contentType = response.header("Content-Type");
		if (contentType != null && contentType.contains("json")) {
			JSONObject jsonObject = new JSONObject(body);

			if (!jsonObject.has("status") || jsonObject.has("success")) {
				if (jsonObject.has("errorcode") && !jsonObject.optString("errorcode", "").isBlank()) {
					throw dealWithException(jsonObject, jsonObject.optString("errorcode", ""));
				} else if (jsonObject.has("errorCode") && !jsonObject.optString("errorCode", "").isBlank()) {
					throw dealWithException(jsonObject, jsonObject.optString("errorCode", ""));
				}
			}
			return jsonObject;
		} else {
			throw new DataException("Unexpected response from Angel One (HTTP " + response.code() + "): "
					+ (body != null && body.length() > 160 ? body.substring(0, 160) : body), "AG8001");
		}
	}

	private SmartAPIException dealWithException(JSONObject jsonObject, String code) throws JSONException {
		String msg = jsonObject.optString("message", "Broker error: " + code);

		switch (code) {
		case "AG8003":
		case "AB8050":
		case "AB8051":
		case "AB1010":
			return new TokenException(msg, code);

		case "AG8001":
			return new TokenException(TOKEN_EXCEPTION_MESSAGE, code);
		case "AG8002":
			return new DataException(msg, code);

		case "AB1004":
		case "AB2000":
			return new GeneralException(msg, code);

		case "AB1003":
		case "AB1005":
		case "AB1012":
		case "AB1002":
			return new InputException(msg, code);

		case "AB1008":
		case "AB1009":
		case "AB1013":
		case "AB1014":
		case "AB1015":
		case "AB1016":
		case "AB1017":
			return new OrderException(msg, code);

		case "NetworkException":
			return new NetworkException(msg, code);

		case "AB1000":
		case "AB1001":
		case "AB1011":
			return new PermissionException(msg, code);
		case "AG8004":
			return new ApiKeyException(APIKEY_EXCEPTION_MESSAGE, code);
		default:
			return new SmartAPIException(msg + " (" + code + ")", code);
		}
	}

    public String handler(Response response, String body) throws SmartAPIException, JSONException, IOException {
        if (response.code() == 200) {
            return handleResponse(response,body);
        } else if (response.code() == 400){
            log.error("Bad request. Please provide valid input");
            return "Bad request. Please provide valid input";
        }else {
            log.error("Response or response body is null.");
            throw new IllegalArgumentException("Response or response body is null.");
        }
    }

    private String handleResponse(Response response, String body) throws SmartAPIException, IOException {
        try {
            JSONObject responseBodyJson = new JSONObject(body);
            if(responseBodyJson.getBoolean("status")) {
                JSONArray dataArray = responseBodyJson.optJSONArray("data");
                if (dataArray != null && dataArray.length() > 0) {
                    List<SearchScripResponseDTO> stockDTOList = parseStockDTOList(dataArray);

                    StringBuilder result = new StringBuilder();
                    result.append("Search successful. Found ").append(stockDTOList.size()).append(" trading symbols for the given query:\n");

                    int index = 1;
                    for (SearchScripResponseDTO stockDTO : stockDTOList) {
                        result.append(index).append(". exchange: ").append(stockDTO.getExchange()).append(", tradingsymbol: ").append(stockDTO.getTradingSymbol()).append(", symboltoken: ").append(stockDTO.getSymbolToken()).append("\n");
                        index++;
                    }
                    return result.toString();
                } else {
                    return "Search successful. No matching trading symbols found for the given query.";
                }
            }else {
                return String.valueOf(handle(response,body));
            }

        } catch (JSONException e) {
            log.error("Error parsing response body as JSON: {}", e.getMessage());
            throw new SmartAPIException("Error parsing response body as JSON.");
        }
    }

    private List<SearchScripResponseDTO> parseStockDTOList(JSONArray dataArray) throws JSONException, SmartAPIException {
        ObjectMapper objectMapper = new ObjectMapper();
        try {
            return objectMapper.readValue(dataArray.toString(), new TypeReference<List<SearchScripResponseDTO>>() {
            });
        } catch (IOException e) {
            log.error("Error parsing JSON data array: {}", e.getMessage());
            throw new SmartAPIException("Error parsing JSON data array.");
        }
    }
}

