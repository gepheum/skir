// Custom Skir language definition for Highlight.js syntax highlighting
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function skirLanguage(hljs: any) {
  const KEYWORDS = {
    keyword: 'struct enum method const import from as removed',
    literal: 'true false',
    type: 'int32 int64 hash64 float32 float64 bool string bytes timestamp',
  }

  return {
    name: 'Skir',
    aliases: ['skir'],
    keywords: KEYWORDS,
    contains: [
      // Doc comments
      {
        className: 'comment',
        begin: '///',
        end: '$',
        relevance: 10,
      },
      // Line comments
      hljs.COMMENT('//', '$'),
      // Block comments
      hljs.COMMENT('/\\*', '\\*/'),
      // Strings
      {
        className: 'string',
        variants: [
          {
            begin: '"',
            end: '"',
            contains: [hljs.BACKSLASH_ESCAPE],
          },
        ],
      },
      // Numbers
      {
        className: 'number',
        variants: [
          { begin: '\\b0x[0-9a-fA-F]+\\b' },
          { begin: '\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b' },
        ],
        relevance: 0,
      },
    ],
  }
}
