import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Package } from 'lucide-react';

interface SOMaterial {
  id: string;
  item_estoque_id: string;
  quantidade: number | null;
  unidade_medida: string | null;
  notas: string | null;
}

interface Props {
  materials: SOMaterial[];
}

export function OSMaterialsCard({ materials }: Props) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base flex items-center gap-2">
          <Package className="h-4 w-4 text-muted-foreground" />
          Materiais Utilizados
        </CardTitle>
      </CardHeader>
      <CardContent>
        {materials.length === 0 ? (
          <p className="text-sm text-muted-foreground">Nenhum material registrado.</p>
        ) : (
          <div className="space-y-2">
            {materials.map((m) => (
              <div key={m.id} className="flex items-center justify-between text-sm">
                <span className="text-foreground">{m.item_estoque_id}</span>
                <span className="text-muted-foreground">
                  {m.quantidade ?? '—'} {m.unidade_medida ?? ''}
                  {m.notas && ` · ${m.notas}`}
                </span>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
