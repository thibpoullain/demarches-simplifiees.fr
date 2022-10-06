import React from 'react';
import { QueryClientProvider } from 'react-query';

import ComboSearch from './ComboSearch';
import { queryClient } from './shared/queryClient';

function ComboFinessSearch(props) {
  return (
    <QueryClientProvider client={queryClient}>
      <ComboSearch
        scope="finess"
        minimumInputLength={3}
        transformResults={(_, { records }) => records}
        transformResult={({
          fields: { finess: id, rs, adresse_lib_routage }
        }) => [id, `${rs}, ${adresse_lib_routage} (${id})`]}
        {...props}
      />
    </QueryClientProvider>
  );
}

export default ComboFinessSearch;
