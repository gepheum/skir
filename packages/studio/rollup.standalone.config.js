import { nodeResolve } from '@rollup/plugin-node-resolve';
import terser from '@rollup/plugin-terser';
import replace from '@rollup/plugin-replace';

export default {
  input: 'dist/app.js',
  output: {
    file: 'dist/skir-studio-standalone.js',
    format: 'iife',
    name: 'SkirStudio',
    sourcemap: true
  },
  plugins: [
    replace({
      'process.env.NODE_ENV': JSON.stringify('production'),
      preventAssignment: true
    }),
    nodeResolve({
      browser: true,
      preferBuiltins: false
    }),
    terser({
      compress: {
        drop_console: false,
        drop_debugger: true
      }
    })
  ]
};
