import osproc
import strformat
import logging

proc uploadToS3(bucket: string, key: string, data: string) =
    try:
        let filePath = "/tmp/" & key
        writeFile(filePath, data)
        let command = fmt"aws s3 cp {filePath} s3://{bucket}/{key}"
        let output = osproc.execShellCmd(command)
        logging.info fmt"Uploaded {key} to S3 bucket {bucket}"
        logging.info output
    except OSError as e:
        logging.error fmt"Failed to upload {key} to S3 bucket {bucket}: {e.msg}"
