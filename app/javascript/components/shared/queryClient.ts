import { QueryClient, QueryFunction } from 'react-query';
import { isNumeric } from '@utils';

type Gon = {
  gon: {
    autocomplete?: {
      api_geo_url?: string;
      api_adresse_url?: string;
      api_education_url?: string;
      api_opendatasoft_url?: string;
    };
  };
};
declare const window: Window & typeof globalThis & Gon;

const API_EDUCATION_QUERY_LIMIT = 5;
const API_GEO_QUERY_LIMIT = 5;
const API_ADRESSE_QUERY_LIMIT = 5;
const API_FINESS_QUERY_LIMIT = 10;
const API_RPPSANTE_QUERY_LIMIT = 10;

// When searching for short strings like "mer", le exact match shows up quite far in
// the ordering (~50).
//
// That's why we deliberately fetch a lot of results, and then let the local matching
// (match-sorter) do the work.
//
// NB: 60 is arbitrary, we may add more if needed.
const API_GEO_COMMUNES_QUERY_LIMIT = 60;

const {
  api_geo_url,
  api_adresse_url,
  api_education_url,
  api_opendatasoft_url
} = window.gon.autocomplete || {};

type QueryKey = readonly [
  scope: string,
  term: string,
  extra: string | undefined
];

function buildURL(scope: string, term: string, extra?: string) {
  const chOpendatasoft = term;
  term = encodeURIComponent(term.replace(/\(|\)/g, ''));
  if (scope === 'adresse') {
    return `${api_adresse_url}/search?q=${term}&limit=${API_ADRESSE_QUERY_LIMIT}`;
  } else if (scope === 'annuaire-education') {
    // console.log("Fetching ANNUAIRE EDUCATION data")
    // console.log(`${api_education_url}/search?dataset=fr-en-annuaire-education&q=${term}&rows=${API_EDUCATION_QUERY_LIMIT}`)
    return `${api_education_url}/search?dataset=fr-en-annuaire-education&q=${term}&rows=${API_EDUCATION_QUERY_LIMIT}`;
  } else if (scope === 'communes') {
    const limit = `limit=${API_GEO_COMMUNES_QUERY_LIMIT}`;
    const url = extra
      ? `${api_geo_url}/communes?codeDepartement=${extra}&${limit}&`
      : `${api_geo_url}/communes?${limit}&`;
    if (isNumeric(term)) {
      return `${url}codePostal=${term}`;
    }
    return `${url}nom=${term}&boost=population`;
  } else if (scope === 'finess') {
    const reg = chOpendatasoft.split(' ');
    let ch = '';
    for (let i = 0; i < reg.length - 1; i++) {
      ch =
        ch +
        '%23search(rs,finess,adresse_lib_routage,adresse_code_postal,"' +
        reg[i] +
        '") AND ';
    }
    ch =
      ch +
      '%23search(rs,finess,adresse_lib_routage,adresse_code_postal,"' +
      reg[reg.length - 1] +
      '")';
    // console.log("Fetching FINESS data")
    // console.log(
    //   `${api_opendatasoft_url}/search?dataset=t_finess&q=${ch}&rows=${API_FINESS_QUERY_LIMIT}&1=1`
    // );
    return `${api_opendatasoft_url}/search?dataset=t_finess&q=${ch}&rows=${API_FINESS_QUERY_LIMIT}`;
  } else if (scope === 'rppsante') {
    const reg = chOpendatasoft.split(' ');
    let ch = '';
    for (let i = 0; i < reg.length - 1; i++) {
      ch =
        ch +
        '%23search(identification_nationale_pp,prenom_d_exercice,libelle_profession,nom_d_exercice,code_postal_coord_structure,libelle_commune_coord_structure,"' +
        reg[i] +
        '") AND ';
    }
    ch =
      ch +
      '%23search(identification_nationale_pp,prenom_d_exercice,libelle_profession,nom_d_exercice,code_postal_coord_structure,libelle_commune_coord_structure,"' +
      reg[reg.length - 1] +
      '")';
    ch = ch + ' AND NOT %23null(libelle_commune_coord_structure) ';
    // console.log("Fetch RPPSANTE data")
    // console.log(
    //   `${api_opendatasoft_url}/search?dataset=ps_libreacces_personne_activite&q=${ch}&rows=${API_RPPSANTE_QUERY_LIMIT}&1=1`
    // );
    return `${api_opendatasoft_url}/search?dataset=ps_libreacces_personne_activite&q=${ch}&rows=${API_RPPSANTE_QUERY_LIMIT}`;
  } else if (isNumeric(term)) {
    const code = term.padStart(2, '0');
    return `${api_geo_url}/${scope}?code=${code}&limit=${API_GEO_QUERY_LIMIT}`;
  }
  return `${api_geo_url}/${scope}?nom=${term}&limit=${API_GEO_QUERY_LIMIT}`;
}

function buildOptions(): [RequestInit, AbortController | null] {
  if (window.AbortController) {
    const controller = new AbortController();
    const signal = controller.signal;
    return [{ signal }, controller];
  }
  return [{}, null];
}

const defaultQueryFn: QueryFunction<unknown, QueryKey> = async ({
  queryKey: [scope, term, extra]
}) => {
  // BAN will error with queries less then 3 chars long
  if (scope == 'adresse' && term.length < 3) {
    return {
      type: 'FeatureCollection',
      version: 'draft',
      features: [],
      query: term
    };
  }

  const url = buildURL(scope, term, extra);
  const [options, controller] = buildOptions();
  const promise = fetch(url, options).then((response) => {
    if (response.ok) {
      return response.json();
    }
    throw new Error(`Error fetching from "${scope}" API`);
  });
  return Object.assign(promise, {
    cancel: () => controller && controller.abort()
  });
};

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // we don't really care about global queryFn type
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      queryFn: defaultQueryFn as any
    }
  }
});
