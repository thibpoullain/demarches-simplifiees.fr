import React from 'react';
import { QueryClientProvider } from 'react-query';

import ComboSearch, { ComboSearchProps } from './ComboSearch';
import { queryClient } from './shared/queryClient';

type FinessResult = {
  fields: {
    id: string;
    rs: string;
    adresse_lib_routage: string;
    adresse_code_postal: string;
    finess: string;
  };
};

function transformResults(_: unknown, result: unknown) {
  const results = result as { records: FinessResult[] };
  return results.records as FinessResult[];
}

export default function ComboFinessSearch(
  props: ComboSearchProps<FinessResult>
) {
  return (
    <QueryClientProvider client={queryClient}>
      <ComboSearch
        {...props}
        scope="finess"
        minimumInputLength={3}
        transformResults={transformResults}
        transformResult={({
          fields: { finess: id, rs, adresse_lib_routage, adresse_code_postal }
        }) => [
          id,
          `${rs}, ${adresse_lib_routage} ${adresse_code_postal} (${id}) `
        ]}
      />
    </QueryClientProvider>
  );
}
