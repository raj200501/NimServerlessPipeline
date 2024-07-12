import json
import logging
import aws_interaction
import data_processor

proc handler(event: JsonNode, context: JsonNode): JsonNode {.exportc.} =
    let data = event["data"].getStr
    logging.info fmt"Received data: {data}"

    # Process the data
    let processedData = data_processor.processData(data)

    # Interact with AWS S3
    aws_interaction.uploadToS3("my-nim-bucket", "processed_data.txt", processedData)

    result = %*{
        "statusCode": 200,
        "body": %*{
            "message": fmt"Processed data: {processedData}"
        }
    }
