import unittest
import json
import handler

suite "Test Lambda Handler":
  test "Handler processes data correctly":
    let event = %*{
      "data": "sample data"
    }
    let context = %*{}
    let response = handler(event, context)
    check response["statusCode"].getInt == 200
    check response["body"]["message"].getStr.contains("PROCESSED DATA")
