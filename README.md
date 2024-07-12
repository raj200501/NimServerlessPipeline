# NimServerlessPipeline

**NimServerlessPipeline** is a serverless data processing pipeline designed to handle data ingestion, processing, and storage efficiently using AWS services. The project leverages Nim for its core functionality, demonstrating its integration with AWS Lambda, AWS S3, AWS DynamoDB, and AWS API Gateway.

## Features

- Serverless architecture using AWS Lambda
- Data ingestion via AWS API Gateway
- Data storage in AWS S3 and AWS DynamoDB
- Advanced data processing using Nim
- Integration with AWS SDKs
- Comprehensive unit tests

## Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/your-username/NimServerlessPipeline.git
    cd NimServerlessPipeline
    ```

2. Build the Nim Lambda function:
    ```bash
    cd backend
    ./build.sh
    ```

3. Deploy the pipeline using AWS SAM:
    ```bash
    cd infrastructure
    ./deploy.sh
    ```

## Usage

- Access the API endpoint via AWS API Gateway
- Monitor data storage in AWS S3 and AWS DynamoDB

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
