import React from 'react';
import { QueryClientProvider } from 'react-query';

import ComboSearch, { ComboSearchProps } from './ComboSearch';
import { queryClient } from './shared/queryClient';

type RppsanteResult = {
  fields: {
    libelle_civilite_d_exercice: string;
    libelle_civilite: string;
    nom_d_exercice: string;
    prenom_d_exercice: string;
    libelle_profession: string;
    identifiant_pp: string;
    code_postal_coord_structure: string;
    libelle_commune_coord_structure: string;
  };
};

function transformResults(_: unknown, result: unknown) {
  const results = result as { records: RppsanteResult[] };
  return results.records as RppsanteResult[];
}

export default function ComboRppsanteSearch(
  props: ComboSearchProps<RppsanteResult>
) {
  return (
    <QueryClientProvider client={queryClient}>
      <ComboSearch
        {...props}
        scope="rppsante"
        minimumInputLength={3}
        transformResults={transformResults}
        transformResult={({
          fields: {
            libelle_civilite_d_exercice,
            libelle_civilite,
            nom_d_exercice,
            prenom_d_exercice,
            libelle_profession,
            identifiant_pp,
            code_postal_coord_structure,
            libelle_commune_coord_structure
          }
        }) => [identifiant_pp,
          `${
            libelle_civilite_d_exercice !== undefined
              ? libelle_civilite_d_exercice
              : libelle_civilite} ${nom_d_exercice} ${prenom_d_exercice}, ${libelle_profession}, ${code_postal_coord_structure} ${libelle_commune_coord_structure} (${identifiant_pp}) `
        ]}
      />
    </QueryClientProvider>
  );
}
