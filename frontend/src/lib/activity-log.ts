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
        condo_id: condoId,
        action,
        entity,
        entity_id: entityId,
        description,
      }),
    });
  } catch (err) {
    console.warn('[logActivity] Error:', err);
  }
}
