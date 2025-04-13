import json
import boto3

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('VisitorCounterTable') 

def lambda_handler(event, context):
    # Update visitor count
    response = table.update_item(
        Key={'id': 'counter'},
        UpdateExpression="SET visitor = visitor + :inc",
        ExpressionAttributeValues={':inc': 1},
        ReturnValues="UPDATED_NEW"
    )

    # Get the updated visitor count
    new_count = int(response['Attributes']['visitor'])

    # Return response
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-control-Allow-Origin': '*',
            'Access-control-Allow-Methods': 'GET',
            'Access-control-Allow-Headers': 'Content-Type'
        },
        'body': json.dumps({'visitor_count': new_count})
    }
