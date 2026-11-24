import { esbuildPlugin } from '@web/dev-server-esbuild';

export default {
  nodeResolve: true,
  watch: true,
  open: false,
  plugins: [
    esbuildPlugin({ ts: true }),
  ],
};
