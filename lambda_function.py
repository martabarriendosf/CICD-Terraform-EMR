import boto3
import gzip
from io import BytesIO

s3 = boto3.client('s3')

def lambda_handler(event, context):
    source_bucket_name = 'mbf-emr-systemfile'
    destination_bucket_name = 'mbf-emr-systemfile-decompress'  # Cambia esto al nombre de tu otro bucket
    prefix = 'monthly_build/2024/logs/'

    # Listar objetos en el bucket de origen
    response = s3.list_objects_v2(Bucket=source_bucket_name, Prefix=prefix)

    # Iterar sobre los objetos
    for obj in response.get('Contents', []):
        key = obj['Key']
        
        # Solo procesar archivos gzip
        if key.endswith('.gz'):
            print(f"Procesando archivo: {key}")

            # Descargar archivo gzip desde S3
            response = s3.get_object(Bucket=source_bucket_name, Key=key)
            gzip_content = response['Body'].read()

            # Descomprimir archivo gzip
            with gzip.GzipFile(fileobj=BytesIO(gzip_content), mode='rb') as f:
                decompressed_data = f.read()

            # Nombre del archivo descomprimido (eliminando la extensión .gz)
            decompressed_key = key[:-3]

            # Subir archivo descomprimido a otro bucket de S3
            s3.put_object(Bucket=destination_bucket_name, Key=decompressed_key, Body=decompressed_data)

            print(f"Archivo descomprimido subido como: {decompressed_key} a {destination_bucket_name}")
       
        elif not key.endswith('/'):
            print(f"Procesando archivo no comprimido: {key}")

            # Descargar archivo no comprimido desde S3
            response = s3.get_object(Bucket=source_bucket_name, Key=key)
            file_content = response['Body'].read()

            # Subir archivo no comprimido a otro bucket de S3
            s3.put_object(Bucket=destination_bucket_name, Key=key, Body=file_content)

            print(f"Archivo no comprimido subido como: {key} a {destination_bucket_name}")


    return {
        'statusCode': 200,
        'body': 'Proceso completado exitosamente'
    }
