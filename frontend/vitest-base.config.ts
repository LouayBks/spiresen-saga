import { defineConfig } from 'vitest/config';

// `pool: 'threads'` is set here, but note it's NOT a confirmed fix for anything — both `forks`
// (Vitest's default) and `threads` hit an identical worker-startup timeout while scaffolding this
// on a memory-constrained WSL dev machine (see DOC/guides/running_locally.md). Left on `threads`
// arbitrarily; revisit if you find a real cause.
export default defineConfig({
  test: {
    pool: 'threads',
    // TS-12: hermetic tests — randomized order surfaces order-dependence as a real failure.
    sequence: {
      shuffle: true,
    },
  },
});
