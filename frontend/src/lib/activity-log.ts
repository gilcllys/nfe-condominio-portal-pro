import { apiFetch } from '@/lib/api';

interface LogActivityParams {
  condoId: string;
  action: 'create' | 'update' | 'delete';
  entity:
    | 'resident'
    | 'condo'
    | 'invoice'
    | 'user'
    | 'user_condo'
    | 'service_order'
    | 'provider'
    | 'contract';
  entityId: string;
  description: string;
}

export async function logActivity({ condoId, action, entity, entityId, description }: LogActivityParams) {
  try {
    await apiFetch('/api/logs-atividade/', {
      method: 'POST',
      body: JSON.stringify({
        condominio_id: condoId,
        acao: action,
        entidade: entity,
        entidade_id: entityId,
        descricao: description,
      }),
    });
  } catch (err) {
    console.warn('[logActivity] Error:', err);
  }
}
