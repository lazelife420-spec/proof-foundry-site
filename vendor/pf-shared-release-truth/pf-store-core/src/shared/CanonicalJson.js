'use strict';

// Proof Foundry Store — shared core canonical serialization (pf-canonical-json-1).
// Deterministic JSON serialization used for every digest and signature input in
// the shared contracts. Objects serialize with recursively sorted keys and no
// insignificant whitespace; array order is preserved. Undefined values are
// rejected (fail closed) rather than silently dropped.

function canonicalize(value, location) {
  const at = location || '$';

  if (value === undefined) {
    throw new TypeError(`CanonicalJson: undefined value at ${at} (fail closed)`);
  }

  if (value === null || typeof value !== 'object') {
    if (typeof value === 'number' && !Number.isFinite(value)) {
      throw new TypeError(`CanonicalJson: non-finite number at ${at} (fail closed)`);
    }
    return JSON.stringify(value);
  }

  if (Array.isArray(value)) {
    const parts = value.map((entry, index) => canonicalize(entry, `${at}[${index}]`));
    return `[${parts.join(',')}]`;
  }

  const keys = Object.keys(value).sort();
  const parts = keys.map(key => `${JSON.stringify(key)}:${canonicalize(value[key], `${at}.${key}`)}`);
  return `{${parts.join(',')}}`;
}

function serialize(value) {
  return canonicalize(value, '$');
}

function sha256Hex(value) {
  return require('crypto').createHash('sha256').update(serialize(value), 'utf8').digest('hex');
}

module.exports = {
  CANONICALIZATION_ID: 'pf-canonical-json-1',
  serialize,
  sha256Hex
};
