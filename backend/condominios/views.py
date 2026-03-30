from datetime import timedelta

from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from common.views import CondominioViewMixin
from condominios.models import (
    Condominio,
    ConfiguracaoFinanceira,
    LogAtividade,
    MembroCondominio,
)
from condominios.serializers import (
    CondominioSerializer,
    ConfiguracaoFinanceiraSerializer,
    LogAtividadeSerializer,
    MembroCondominioSerializer,
)


class CondominioViewSet(mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    serializer_class = CondominioSerializer
    queryset = Condominio.objects.all()
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=["get"], url_path="meus")
    def meus_condominios(self, request):
        """GET /api/condominios/meus/ - lista condominios do usuario."""
        membros = MembroCondominio.objects.filter(
            usuario=request.user, status=MembroCondominio.Status.ATIVO
        ).select_related("condominio")

        resultado = []
        for m in membros:
            resultado.append(
                {
                    "condominio_id": str(m.condominio_id),
                    "condominio_nome": m.condominio.nome,
                    "papel": m.papel,
                    "padrao": m.padrao,
                }
            )
        return Response(resultado)

    @action(detail=False, methods=["get"], url_path="contexto-ativo")
    def contexto_ativo(self, request):
        """GET /api/condominios/contexto-ativo/ - condominio ativo do usuario."""
        membro = (
            MembroCondominio.objects.filter(
                usuario=request.user, status=MembroCondominio.Status.ATIVO
            )
            .select_related("condominio")
            .order_by("-padrao", "-criado_em")
            .first()
        )
        if not membro:
            return Response(None)

        return Response(
            {
                "condominio_id": str(membro.condominio_id),
                "condominio_nome": membro.condominio.nome,
                "papel": membro.papel,
            }
        )

    @action(detail=False, methods=["post"], url_path="trocar")
    def trocar_condominio(self, request):
        """POST /api/condominios/trocar/ - troca condominio ativo."""
        condominio_id = request.data.get("condominio_id")
        if not condominio_id:
            return Response(
                {"error": "condominio_id e obrigatorio"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        MembroCondominio.objects.filter(usuario=request.user).update(padrao=False)
        atualizado = MembroCondominio.objects.filter(
            usuario=request.user,
            condominio_id=condominio_id,
            status=MembroCondominio.Status.ATIVO,
        ).update(padrao=True)

        if not atualizado:
            return Response(
                {"error": "Condominio nao encontrado ou sem acesso"},
                status=status.HTTP_404_NOT_FOUND,
            )

        membro = (
            MembroCondominio.objects.filter(
                usuario=request.user, condominio_id=condominio_id
            )
            .select_related("condominio")
            .first()
        )

        return Response(
            {
                "condominio_id": str(membro.condominio_id),
                "condominio_nome": membro.condominio.nome,
                "papel": membro.papel,
            }
        )

    @action(detail=False, methods=["post"], url_path="criar")
    def criar_condominio(self, request):
        """POST /api/condominios/criar/ - cria novo condominio."""
        nome = request.data.get("nome", "").strip()
        documento = request.data.get("documento", "").strip() or None

        if not nome:
            return Response(
                {"error": "Nome e obrigatorio"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        condominio = Condominio.objects.create(
            nome=nome,
            documento=documento,
            status_assinatura="trial",
            assinatura_expira_em=timezone.now() + timedelta(days=7),
        )
        MembroCondominio.objects.create(
            usuario=request.user,
            condominio=condominio,
            papel=MembroCondominio.Papel.SINDICO,
            status=MembroCondominio.Status.ATIVO,
            padrao=True,
        )
        ConfiguracaoFinanceira.objects.create(condominio=condominio)

        return Response(
            {"success": True, "condominio_id": str(condominio.id)},
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["patch"], url_path="atualizar")
    def atualizar_condominio(self, request, pk=None):
        campos_permitidos = ["nome", "documento", "endereco", "cidade", "estado", "cep", "telefone", "email"]
        atualizacoes = {k: v for k, v in request.data.items() if k in campos_permitidos}
        if not atualizacoes:
            return Response(
                {"error": "Nenhum campo para atualizar"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        Condominio.objects.filter(id=pk).update(**atualizacoes)
        return Response({"success": True})

    @action(detail=True, methods=["get"], url_path="cobranca")
    def cobranca(self, request, pk=None):
        try:
            c = Condominio.objects.get(id=pk)
            return Response(
                {
                    "nome": c.nome,
                    "status_assinatura": c.status_assinatura,
                    "assinatura_id": c.assinatura_id,
                    "assinatura_expira_em": (
                        c.assinatura_expira_em.isoformat()
                        if c.assinatura_expira_em
                        else None
                    ),
                }
            )
        except Condominio.DoesNotExist:
            return Response(None, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=["get", "put"], url_path="config-financeira")
    def config_financeira(self, request, pk=None):
        if request.method == "GET":
            try:
                cfg = ConfiguracaoFinanceira.objects.get(condominio_id=pk)
                serializer = ConfiguracaoFinanceiraSerializer(cfg)
                return Response(serializer.data)
            except ConfiguracaoFinanceira.DoesNotExist:
                return Response(None)

        cfg, _ = ConfiguracaoFinanceira.objects.get_or_create(condominio_id=pk)
        campos = [
            "alcada_1_limite", "alcada_2_limite", "alcada_3_limite",
            "prazo_aprovacao_horas", "notificar_moradores_acima",
            "limite_mensal_manutencao", "limite_mensal_limpeza",
            "limite_mensal_seguranca", "orcamento_anual", "alerta_orcamento_pct",
            "orcamento_mensal",
        ]
        for campo in campos:
            if campo in request.data:
                setattr(cfg, campo, request.data[campo])
        cfg.save()
        return Response({"success": True})

    @action(
        detail=False,
        methods=["get"],
        url_path="validar-convite",
        authentication_classes=[],
        permission_classes=[AllowAny],
    )
    def validar_convite(self, request):
        codigo = request.query_params.get("codigo", "")
        if not codigo:
            return Response(None)
        try:
            c = Condominio.objects.get(codigo_convite=codigo, convite_ativo=True)
            return Response({"id": str(c.id), "nome": c.nome})
        except Condominio.DoesNotExist:
            return Response(None)

    @action(detail=False, methods=["get"], url_path="dashboard-stats")
    def dashboard_stats(self, request):
        """GET /api/condominios/dashboard-stats/?condominio_id=... — stats do dashboard."""
        condominio_id = request.query_params.get("condominio_id")
        if not condominio_id:
            return Response(
                {"nfs_pendentes": 0, "aprovacoes_pendentes": 0, "budget_total": 0, "budget_used": 0}
            )

        from fiscal.models import DocumentoFiscal
        from ordens.models import OrdemServico

        nfs_pendentes = DocumentoFiscal.objects.filter(
            condominio_id=condominio_id, status="PENDENTE"
        ).count()

        aprovacoes_pendentes = OrdemServico.objects.filter(
            condominio_id=condominio_id, status="AGUARDANDO_APROVACAO"
        ).count()

        # Orcamento mensal
        budget_total = 0
        budget_used = 0
        try:
            cfg = ConfiguracaoFinanceira.objects.get(condominio_id=condominio_id)
            budget_total = float(cfg.orcamento_mensal or 0)
        except ConfiguracaoFinanceira.DoesNotExist:
            pass

        return Response(
            {
                "nfs_pendentes": nfs_pendentes,
                "aprovacoes_pendentes": aprovacoes_pendentes,
                "budget_total": budget_total,
                "budget_used": budget_used,
            }
        )


class MembroCondominioViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.UpdateModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = MembroCondominioSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = MembroCondominio.objects.all()
        usuario_id = self.request.query_params.get("usuario_id")
        condominio_id = self.request.query_params.get("condominio_id")
        status_filtro = self.request.query_params.get("status")
        papel_in = self.request.query_params.get("papel__in")

        if usuario_id:
            qs = qs.filter(usuario_id=usuario_id)
        if condominio_id:
            qs = qs.filter(condominio_id=condominio_id)
        if status_filtro:
            qs = qs.filter(status=status_filtro)
        if papel_in:
            qs = qs.filter(papel__in=papel_in.split(","))
        return qs

    @action(detail=False, methods=["post"], url_path="alterar-papel")
    def alterar_papel(self, request):
        membro_id = request.data.get("membro_id")
        novo_papel = request.data.get("novo_papel")
        if not membro_id or not novo_papel:
            return Response(
                {"error": "membro_id e novo_papel sao obrigatorios"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            membro = MembroCondominio.objects.get(id=membro_id)
            membro.papel = novo_papel
            membro.save(update_fields=["papel", "atualizado_em"])
            return Response({"success": True})
        except MembroCondominio.DoesNotExist:
            return Response(
                {"error": "Membro nao encontrado"},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=False, methods=["post"], url_path="aprovar")
    def aprovar(self, request):
        usuario_id = request.data.get("usuario_id")
        condominio_id = request.data.get("condominio_id")
        if not usuario_id or not condominio_id:
            return Response(
                {"error": "usuario_id e condominio_id sao obrigatorios"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        MembroCondominio.objects.filter(
            usuario_id=usuario_id, condominio_id=condominio_id
        ).update(status=MembroCondominio.Status.ATIVO)
        return Response({"success": True})

    @action(detail=False, methods=["post"], url_path="recusar")
    def recusar(self, request):
        usuario_id = request.data.get("usuario_id")
        condominio_id = request.data.get("condominio_id")
        if not usuario_id or not condominio_id:
            return Response(
                {"error": "usuario_id e condominio_id sao obrigatorios"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        MembroCondominio.objects.filter(
            usuario_id=usuario_id, condominio_id=condominio_id
        ).update(status=MembroCondominio.Status.RECUSADO)
        return Response({"success": True})


class LogAtividadeViewSet(
    CondominioViewMixin,
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = LogAtividadeSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = LogAtividade.objects.all()
        condominio_id = self.get_condominio_id()
        if condominio_id:
            qs = qs.filter(condominio_id=condominio_id)
        else:
            return LogAtividade.objects.none()
        limite = int(self.request.query_params.get("limite", 20))
        return qs.order_by("-criado_em")[:limite]

    def perform_create(self, serializer):
        serializer.save(usuario=self.request.user)
