import React from 'react';
import { QueryClientProvider } from 'react-query';

import ComboSearch from './ComboSearch';
import { queryClient } from './shared/queryClient';

function ComboRppsanteSearch(props) {
  return (
    <QueryClientProvider client={queryClient}>
      <ComboSearch
        scope="rppsante"
        minimumInputLength={3}
        transformResults={(_, { records }) => records}
        transformResult={({
          fields: {
            libelle_civilite_d_exercice,
            libelle_civilite,
            nom_d_exercice,
            prenom_d_exercice,
            libelle_profession,
            identification_nationale_pp,
            code_postal_coord_structure,
            libelle_commune_coord_structure
          }
        }) => [
          identification_nationale_pp,
          `${
            libelle_civilite_d_exercice !== undefined
              ? libelle_civilite_d_exercice
              : libelle_civilite
          } ${nom_d_exercice} ${prenom_d_exercice}, ${libelle_profession}, ${code_postal_coord_structure} ${libelle_commune_coord_structure} (${identification_nationale_pp}) `
        ]}
        {...props}
      />
    </QueryClientProvider>
  );
}

export default ComboRppsanteSearch;
