"""
View generica de upload de arquivos.

Recebe multipart/form-data com:
  - file: o arquivo em si
  - bucket: nome logico do bucket (ex: service-order-photos, nfe-vigia)
  - path: caminho relativo dentro do bucket

Salva em MEDIA_ROOT/<bucket>/<path> e retorna a URL publica.
"""

import os

from django.conf import settings
from rest_framework import status
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView


class FileUploadView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def post(self, request):
        uploaded_file = request.FILES.get("file")
        if not uploaded_file:
            return Response(
                {"error": "Nenhum arquivo enviado"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        bucket = request.data.get("bucket", "uploads")
        path = request.data.get("path", uploaded_file.name)

        # Sanitize: impedir path traversal
        path = path.replace("..", "").lstrip("/")
        bucket = bucket.replace("..", "").lstrip("/")

        dest_dir = os.path.join(settings.MEDIA_ROOT, bucket, os.path.dirname(path))
        os.makedirs(dest_dir, exist_ok=True)

        dest_path = os.path.join(settings.MEDIA_ROOT, bucket, path)

        with open(dest_path, "wb+") as f:
            for chunk in uploaded_file.chunks():
                f.write(chunk)

        url = f"{settings.MEDIA_URL}{bucket}/{path}"

        return Response(
            {"url": url, "path": f"{bucket}/{path}"},
            status=status.HTTP_201_CREATED,
        )
