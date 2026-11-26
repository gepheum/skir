<script setup lang="ts">
import HoverVideo from './HoverVideo.vue'
import QuickstartPill from './QuickstartPill.vue'

const languages = [
  {
    name: 'TypeScript',
    href: '/docs/typescript',
    colorClass: 'lang-icon-ts',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M1.125 0C.502 0 0 .502 0 1.125v21.75C0 23.498.502 24 1.125 24h21.75c.623 0 1.125-.502 1.125-1.125V1.125C24 .502 23.498 0 22.875 0zm17.363 9.75c.612 0 1.154.037 1.627.111a6.38 6.38 0 0 1 1.306.34v2.458a3.95 3.95 0 0 0-.643-.361 5.093 5.093 0 0 0-.717-.26 5.453 5.453 0 0 0-1.426-.2c-.3 0-.573.028-.819.086a2.1 2.1 0 0 0-.623.242c-.17.104-.3.229-.393.374a.888.888 0 0 0-.14.49c0 .196.053.373.156.529.104.156.252.304.443.444s.423.276.696.41c.273.135.582.274.926.416.47.197.892.407 1.266.628.374.222.695.473.963.753.268.279.472.598.614.957.142.359.214.776.214 1.253 0 .657-.125 1.21-.373 1.656a3.033 3.033 0 0 1-1.012 1.085 4.38 4.38 0 0 1-1.487.596c-.566.12-1.163.18-1.79.18a9.916 9.916 0 0 1-1.84-.164 5.544 5.544 0 0 1-1.512-.493v-2.63a5.033 5.033 0 0 0 3.237 1.2c.333 0 .624-.03.872-.09.249-.06.456-.144.623-.25.166-.108.29-.234.373-.38a1.023 1.023 0 0 0-.074-1.089 2.12 2.12 0 0 0-.537-.5 5.597 5.597 0 0 0-.807-.444 27.72 27.72 0 0 0-1.007-.436c-.918-.383-1.602-.852-2.053-1.405-.45-.553-.676-1.222-.676-2.005 0-.614.123-1.141.369-1.582.246-.441.58-.804 1.004-1.089a4.494 4.494 0 0 1 1.47-.629 7.536 7.536 0 0 1 1.77-.201zm-15.113.188h9.563v2.166H9.506v9.646H6.789v-9.646H3.375z"/></svg>',
  },
  {
    name: 'Python',
    href: '/docs/python',
    colorClass: 'lang-icon-py',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M14.25.18l.9.2.73.26.59.3.45.32.34.34.25.34.16.33.1.3.04.26.02.2-.01.13V8.5l-.05.63-.13.55-.21.46-.26.38-.3.31-.33.25-.35.19-.35.14-.33.1-.3.07-.26.04-.21.02H8.77l-.69.05-.59.14-.5.22-.41.27-.33.32-.27.35-.2.36-.15.37-.1.35-.07.32-.04.27-.02.21v3.06H3.17l-.21-.03-.28-.07-.32-.12-.35-.18-.36-.26-.36-.36-.35-.46-.32-.59-.28-.73-.21-.88-.14-1.05-.05-1.23.06-1.22.16-1.04.24-.87.32-.71.36-.57.4-.44.42-.33.42-.24.4-.16.36-.1.32-.05.24-.01h.16l.06.01h8.16v-.83H6.18l-.01-2.75-.02-.37.05-.34.11-.31.17-.28.25-.26.31-.23.38-.2.44-.18.51-.15.58-.12.64-.1.71-.06.77-.04.84-.02 1.27.05zm-6.3 1.98l-.23.33-.08.41.08.41.23.34.33.22.41.09.41-.09.33-.22.23-.34.08-.41-.08-.41-.23-.33-.33-.22-.41-.09-.41.09zm13.09 3.95l.28.06.32.12.35.18.36.27.36.35.35.47.32.59.28.73.21.88.14 1.04.05 1.23-.06 1.23-.16 1.04-.24.86-.32.71-.36.57-.4.45-.42.33-.42.24-.4.16-.36.09-.32.05-.24.02-.16-.01h-8.22v.82h5.84l.01 2.76.02.36-.05.34-.11.31-.17.29-.25.25-.31.24-.38.2-.44.17-.51.15-.58.13-.64.09-.71.07-.77.04-.84.01-1.27-.04-1.07-.14-.9-.2-.73-.25-.59-.3-.45-.33-.34-.34-.25-.34-.16-.33-.1-.3-.04-.25-.02-.2.01-.13v-5.34l.05-.64.13-.54.21-.46.26-.38.3-.32.33-.24.35-.2.35-.14.33-.1.3-.06.26-.04.21-.02.13-.01h5.84l.69-.05.59-.14.5-.21.41-.28.33-.32.27-.35.2-.36.15-.36.1-.35.07-.32.04-.28.02-.21V6.07h2.09l.14.01zm-6.47 14.25l-.23.33-.08.41.08.41.23.33.33.23.41.08.41-.08.33-.23.23-.33.08-.41-.08-.41-.23-.33-.33-.23-.41-.08-.41.08z"/></svg>',
  },
  {
    name: 'Java',
    href: '/docs/java',
    colorClass: 'lang-icon-java',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 384 512" width="24" height="24" fill="currentColor"><path d="M277.74 312.9c9.8-6.7 23.4-12.5 23.4-12.5s-38.7 7-77.2 10.2c-47.1 3.9-97.7 4.7-123.1 1.3-60.1-8 33-30.1 33-30.1s-36.1-2.4-80.6 19c-52.5 25.4 130 37 224.5 12.1zm-85.4-32.1c-19-42.7-83.1-80.2 0-145.8C296 53.2 242.84 0 242.84 0c21.5 84.5-75.6 110.1-110.7 162.6-23.9 35.9 11.7 74.4 60.2 118.2zm114.6-176.2c.1 0-175.2 43.8-91.5 140.2 24.7 28.4-6.5 54-6.5 54s62.7-32.4 33.9-72.9c-26.9-37.8-47.5-56.6 64.1-121.3zm-6.1 270.5a12.19 12.19 0 0 1-2 2.6c128.3-33.7 81.1-118.9 19.8-97.3a17.33 17.33 0 0 0-8.2 6.3 70.45 70.45 0 0 1 11-3c31-6.5 75.5 41.5-20.6 91.4zM348 437.4s14.5 11.9-15.9 21.2c-57.9 17.5-240.8 22.8-291.6.7-18.3-7.9 16-19 26.8-21.3 11.2-2.4 17.7-2 17.7-2-20.3-14.3-131.3 28.1-56.4 40.2C232.84 509.4 401 461.3 348 437.4zM124.44 396c-78.7 22 47.9 67.4 148.1 24.5a185.89 185.89 0 0 1-28.2-13.8c-44.7 8.5-65.4 9.1-106 4.5-33.5-3.8-13.9-15.2-13.9-15.2zm179.8 97.2c-78.7 14.8-175.8 13.1-233.3 3.6 0-.1 11.8 9.7 72.4 13.6 92.2 5.9 233.8-3.3 237.1-46.9 0 0-6.4 16.5-76.2 29.7zM260.64 353c-59.2 11.4-93.5 11.1-136.8 6.6-33.5-3.5-11.6-19.7-11.6-19.7-86.8 28.8 48.2 61.4 169.5 25.9a60.37 60.37 0 0 1-21.1-12.8z"/></svg>',
  },
  {
    name: 'C#',
    href: '/docs/csharp',
    colorClass: 'lang-icon-csharp',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M14.2209.0875v5.9613l-3.7433.5012v3.5233l3.7433-.5012v3.5735l3.492-.4672V9.1047L24 8.2634l-.4631-3.4613-5.824.7794V.0875zM6.287 1.145v5.9618L0 7.9483l.4634 3.4613 5.8514-.7834 3.4644-.4637V1.145zm3.5198 9.7185l-3.492.4675v3.578l-6.183.8276.4633 3.4613 5.8239-.7796v5.4942h3.492v-5.962l3.6114-.4834V13.944l-3.7156.4973zm13.73 1.7405l-5.824.779-3.492.4673v9.0179h3.492v-5.9618L24 16.0652Z"/></svg>',
  },
  {
    name: 'C++',
    href: '/docs/cpp',
    colorClass: 'lang-icon-cpp',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M22.394 6c-.167-.29-.398-.543-.652-.69L12.926.22c-.509-.294-1.34-.294-1.848 0L2.26 5.31c-.508.293-.923 1.013-.923 1.6v10.18c0 .294.104.62.271.91.167.29.398.543.652.69l8.816 5.09c.508.293 1.34.293 1.848 0l8.816-5.09c.254-.147.485-.4.652-.69.167-.29.27-.616.27-.91V6.91c.003-.294-.1-.62-.268-.91zM12 19.11c-3.92 0-7.109-3.19-7.109-7.11 0-3.92 3.19-7.11 7.11-7.11a7.133 7.133 0 016.156 3.553l-3.076 1.78a3.567 3.567 0 00-3.08-1.78A3.56 3.56 0 008.444 12 3.56 3.56 0 0012 15.555a3.57 3.57 0 003.08-1.778l3.078 1.78A7.135 7.135 0 0112 19.11zm7.11-6.715h-.79v.79h-.79v-.79h-.79v-.79h.79v-.79h.79v.79h.79zm2.962 0h-.79v.79h-.79v-.79h-.79v-.79h.79v-.79h.79v.79h.79z"/></svg>',
  },
  {
    name: 'Go',
    href: '/docs/go',
    colorClass: 'lang-icon-go',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M1.811 10.231c-.047 0-.058-.023-.035-.059l.246-.315c.023-.035.081-.058.128-.058h4.172c.046 0 .058.035.035.07l-.199.303c-.023.036-.082.07-.117.07zM.047 11.306c-.047 0-.059-.023-.035-.058l.245-.316c.023-.035.082-.058.129-.058h5.328c.047 0 .07.035.058.07l-.093.28c-.012.047-.058.07-.105.07zm2.828 1.075c-.047 0-.059-.035-.035-.07l.163-.292c.023-.035.07-.07.117-.07h2.337c.047 0 .07.035.07.082l-.023.28c0 .047-.047.082-.082.082zm12.129-2.36c-.736.187-1.239.327-1.963.514-.176.046-.187.058-.34-.117-.174-.199-.303-.327-.548-.444-.737-.362-1.45-.257-2.115.175-.795.514-1.204 1.274-1.192 2.22.011.935.654 1.706 1.577 1.835.795.105 1.46-.175 1.987-.77.105-.13.198-.27.315-.434H10.47c-.245 0-.304-.152-.222-.35.152-.362.432-.97.596-1.274a.315.315 0 01.292-.187h4.253c-.023.316-.023.631-.07.947a4.983 4.983 0 01-.958 2.29c-.841 1.11-1.94 1.8-3.33 1.986-1.145.152-2.209-.07-3.143-.77-.865-.655-1.356-1.52-1.484-2.595-.152-1.274.222-2.419.993-3.424.83-1.086 1.928-1.776 3.272-2.02 1.098-.2 2.15-.07 3.096.571.62.41 1.063.97 1.356 1.648.07.105.023.164-.117.2m3.868 6.461c-1.064-.024-2.034-.328-2.852-1.029a3.665 3.665 0 01-1.262-2.255c-.21-1.32.152-2.489.947-3.529.853-1.122 1.881-1.706 3.272-1.95 1.192-.21 2.314-.095 3.33.595.923.63 1.496 1.484 1.648 2.605.198 1.578-.257 2.863-1.344 3.962-.771.783-1.718 1.273-2.805 1.495-.315.06-.63.07-.934.106zm2.78-4.72c-.011-.153-.011-.27-.034-.387-.21-1.157-1.274-1.81-2.384-1.554-1.087.245-1.788.935-2.045 2.033-.21.912.234 1.835 1.075 2.21.643.28 1.285.244 1.905-.07.923-.48 1.425-1.228 1.484-2.233z"/></svg>',
  },
  {
    name: 'Kotlin',
    href: '/docs/kotlin',
    colorClass: 'lang-icon-kotlin',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M24 24H0V0h24L12 12Z"/></svg>',
  },
  {
    name: 'Dart',
    href: '/docs/dart',
    colorClass: 'lang-icon-dart',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M4.105 4.105S9.158 1.58 11.684.316a3.079 3.079 0 0 1 1.481-.315c.766.047 1.677.788 1.677.788L24 9.948v9.789h-4.263V24H9.789l-9-9C.303 14.5 0 13.795 0 13.105c0-.319.18-.818.316-1.105l3.789-7.895zm.679.679v11.787c.002.543.021 1.024.498 1.508L10.204 23h8.533v-4.263L4.784 4.784zm12.055-.678c-.899-.896-1.809-1.78-2.74-2.643-.302-.267-.567-.468-1.07-.462-.37.014-.87.195-.87.195L6.341 4.105l10.498.001z"/></svg>',
  },
  {
    name: 'Swift',
    href: '/docs/swift',
    colorClass: 'lang-icon-swift',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M7.508 0c-.287 0-.573 0-.86.002-.241.002-.483.003-.724.01-.132.003-.263.009-.395.015A9.154 9.154 0 0 0 4.348.15 5.492 5.492 0 0 0 2.85.645 5.04 5.04 0 0 0 .645 2.848c-.245.48-.4.972-.495 1.5-.093.52-.122 1.05-.136 1.576a35.2 35.2 0 0 0-.012.724C0 6.935 0 7.221 0 7.508v8.984c0 .287 0 .575.002.862.002.24.005.481.012.722.014.526.043 1.057.136 1.576.095.528.25 1.02.495 1.5a5.03 5.03 0 0 0 2.205 2.203c.48.244.97.4 1.498.495.52.093 1.05.124 1.576.138.241.007.483.009.724.01.287.002.573.002.86.002h8.984c.287 0 .573 0 .86-.002.241-.001.483-.003.724-.01a10.523 10.523 0 0 0 1.578-.138 5.322 5.322 0 0 0 1.498-.495 5.035 5.035 0 0 0 2.203-2.203c.245-.48.4-.972.495-1.5.093-.52.124-1.05.138-1.576.007-.241.009-.481.01-.722.002-.287.002-.575.002-.862V7.508c0-.287 0-.573-.002-.86a33.662 33.662 0 0 0-.01-.724 10.5 10.5 0 0 0-.138-1.576 5.328 5.328 0 0 0-.495-1.5A5.039 5.039 0 0 0 21.152.645 5.32 5.32 0 0 0 19.654.15a10.493 10.493 0 0 0-1.578-.138 34.98 34.98 0 0 0-.722-.01C17.067 0 16.779 0 16.492 0H7.508zm6.035 3.41c4.114 2.47 6.545 7.162 5.549 11.131-.024.093-.05.181-.076.272l.002.001c2.062 2.538 1.5 5.258 1.236 4.745-1.072-2.086-3.066-1.568-4.088-1.043a6.803 6.803 0 0 1-.281.158l-.02.012-.002.002c-2.115 1.123-4.957 1.205-7.812-.022a12.568 12.568 0 0 1-5.64-4.838c.649.48 1.35.902 2.097 1.252 3.019 1.414 6.051 1.311 8.197-.002C9.651 12.73 7.101 9.67 5.146 7.191a10.628 10.628 0 0 1-1.005-1.384c2.34 2.142 6.038 4.83 7.365 5.576C8.69 8.408 6.208 4.743 6.324 4.86c4.436 4.47 8.528 6.996 8.528 6.996.154.085.27.154.36.213.085-.215.16-.437.224-.668.708-2.588-.09-5.548-1.893-7.992z"/></svg>',
  },
  {
    name: 'Rust',
    href: '/docs/rust',
    colorClass: 'lang-icon-rust',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M23.8346 11.7033l-1.0073-.6236a13.7268 13.7268 0 00-.0283-.2936l.8656-.8069a.3483.3483 0 00-.1154-.578l-1.1066-.414a8.4958 8.4958 0 00-.087-.2856l.6904-.9587a.3462.3462 0 00-.2257-.5446l-1.1663-.1894a9.3574 9.3574 0 00-.1407-.2622l.49-1.0761a.3437.3437 0 00-.0274-.3361.3486.3486 0 00-.3006-.154l-1.1845.0416a6.7444 6.7444 0 00-.1873-.2268l.2723-1.153a.3472.3472 0 00-.417-.4172l-1.1532.2724a14.0183 14.0183 0 00-.2278-.1873l.0415-1.1845a.3442.3442 0 00-.49-.328l-1.076.491c-.0872-.0476-.1742-.0952-.2623-.1407l-.1903-1.1673A.3483.3483 0 0016.256.955l-.9597.6905a8.4867 8.4867 0 00-.2855-.086l-.414-1.1066a.3483.3483 0 00-.5781-.1154l-.8069.8666a9.2936 9.2936 0 00-.2936-.0284L12.2946.1683a.3462.3462 0 00-.5892 0l-.6236 1.0073a13.7383 13.7383 0 00-.2936.0284L9.9803.3374a.3462.3462 0 00-.578.1154l-.4141 1.1065c-.0962.0274-.1903.0567-.2855.086L7.744.955a.3483.3483 0 00-.5447.2258L7.009 2.348a9.3574 9.3574 0 00-.2622.1407l-1.0762-.491a.3462.3462 0 00-.49.328l.0416 1.1845a7.9826 7.9826 0 00-.2278.1873L3.8413 3.425a.3472.3472 0 00-.4171.4171l.2713 1.1531c-.0628.075-.1255.1509-.1863.2268l-1.1845-.0415a.3462.3462 0 00-.328.49l.491 1.0761a9.167 9.167 0 00-.1407.2622l-1.1662.1894a.3483.3483 0 00-.2258.5446l.6904.9587a13.303 13.303 0 00-.087.2855l-1.1065.414a.3483.3483 0 00-.1155.5781l.8656.807a9.2936 9.2936 0 00-.0283.2935l-1.0073.6236a.3442.3442 0 000 .5892l1.0073.6236c.008.0982.0182.1964.0283.2936l-.8656.8079a.3462.3462 0 00.1155.578l1.1065.4141c.0273.0962.0567.1914.087.2855l-.6904.9587a.3452.3452 0 00.2268.5447l1.1662.1893c.0456.088.0922.1751.1408.2622l-.491 1.0762a.3462.3462 0 00.328.49l1.1834-.0415c.0618.0769.1235.1528.1873.2277l-.2713 1.1541a.3462.3462 0 00.4171.4161l1.153-.2713c.075.0638.151.1255.2279.1863l-.0415 1.1845a.3442.3442 0 00.49.327l1.0761-.49c.087.0486.1741.0951.2622.1407l.1903 1.1662a.3483.3483 0 00.5447.2268l.9587-.6904a9.299 9.299 0 00.2855.087l.414 1.1066a.3452.3452 0 00.5781.1154l.8079-.8656c.0972.0111.1954.0203.2936.0294l.6236 1.0073a.3472.3472 0 00.5892 0l.6236-1.0073c.0982-.0091.1964-.0183.2936-.0294l.8069.8656a.3483.3483 0 00.578-.1154l.4141-1.1066a8.4626 8.4626 0 00.2855-.087l.9587.6904a.3452.3452 0 00.5447-.2268l.1903-1.1662c.088-.0456.1751-.0931.2622-.1407l1.0762.49a.3472.3472 0 00.49-.327l-.0415-1.1845a6.7267 6.7267 0 00.2267-.1863l1.1531.2713a.3472.3472 0 00.4171-.416l-.2713-1.1542c.0628-.0749.1255-.1508.1863-.2278l1.1845.0415a.3442.3442 0 00.328-.49l-.49-1.076c.0475-.0872.0951-.1742.1407-.2623l1.1662-.1893a.3483.3483 0 00.2258-.5447l-.6904-.9587.087-.2855 1.1066-.414a.3462.3462 0 00.1154-.5781l-.8656-.8079c.0101-.0972.0202-.1954.0283-.2936l1.0073-.6236a.3442.3442 0 000-.5892zm-6.7413 8.3551a.7138.7138 0 01.2986-1.396.714.714 0 11-.2997 1.396zm-.3422-2.3142a.649.649 0 00-.7715.5l-.3573 1.6685c-1.1035.501-2.3285.7795-3.6193.7795a8.7368 8.7368 0 01-3.6951-.814l-.3574-1.6684a.648.648 0 00-.7714-.499l-1.473.3158a8.7216 8.7216 0 01-.7613-.898h7.1676c.081 0 .1356-.0141.1356-.088v-2.536c0-.074-.0536-.0881-.1356-.0881h-2.0966v-1.6077h2.2677c.2065 0 1.1065.0587 1.394 1.2088.0901.3533.2875 1.5044.4232 1.8729.1346.413.6833 1.2381 1.2685 1.2381h3.5716a.7492.7492 0 00.1296-.0131 8.7874 8.7874 0 01-.8119.9526zM6.8369 20.024a.714.714 0 11-.2997-1.396.714.714 0 01.2997 1.396zM4.1177 8.9972a.7137.7137 0 11-1.304.5791.7137.7137 0 011.304-.579zm-.8352 1.9813l1.5347-.6824a.65.65 0 00.33-.8585l-.3158-.7147h1.2432v5.6025H3.5669a8.7753 8.7753 0 01-.2834-3.348zm6.7343-.5437V8.7836h2.9601c.153 0 1.0792.1772 1.0792.8697 0 .575-.7107.7815-1.2948.7815zm10.7574 1.4862c0 .2187-.008.4363-.0243.651h-.9c-.09 0-.1265.0586-.1265.1477v.413c0 .973-.5487 1.1846-1.0296 1.2382-.4576.0517-.9648-.1913-1.0275-.4717-.2704-1.5186-.7198-1.8436-1.4305-2.4034.8817-.5599 1.799-1.386 1.799-2.4915 0-1.1936-.819-1.9458-1.3769-2.3153-.7825-.5163-1.6491-.6195-1.883-.6195H5.4682a8.7651 8.7651 0 014.907-2.7699l1.0974 1.151a.648.648 0 00.9182.0213l1.227-1.1743a8.7753 8.7753 0 016.0044 4.2762l-.8403 1.8982a.652.652 0 00.33.8585l1.6178.7188c.0283.2875.0425.577.0425.8717zm-9.3006-9.5993a.7128.7128 0 11.984 1.0316.7137.7137 0 01-.984-1.0316zm8.3389 6.71a.7107.7107 0 01.9395-.3625.7137.7137 0 11-.9405.3635z"/></svg>',
  },
  {
    name: 'Zig',
    href: '/docs/zig',
    colorClass: 'lang-icon-zig',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="m23.53 1.02-7.686 3.45h-7.06l-2.98 3.452h7.173L.47 22.98l7.681-3.607h7.065v-.002l2.978-3.45-7.148-.001 12.482-14.9zM0 4.47v14.901h1.883l2.98-3.45H3.451v-8h.942l2.824-3.45H0zm22.117 0-2.98 3.608h1.412v7.844h-.942l-2.98 3.45H24V4.47h-1.883z"/></svg>',
  },
  {
    name: 'Gleam',
    href: '/docs/gleam',
    colorClass: 'lang-icon-gleam',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M10.6144.0026a1.9 1.9 0 0 0-.229.0261l.0001.0002C9.78.1358 9.2263.538 8.9971 1.1873l-1.7855 5.059A1.8 1.8 0 0 1 6.1704 7.323L1.1706 9.282c-1.283.5027-1.531 2.2673-.4373 3.1027l4.2646 3.257a1.795 1.795 0 0 1 .7031 1.3212l.3179 5.3537c.0815 1.3735 1.6836 2.1548 2.819 1.3729v-.0002l4.4212-3.0459v-.0001a1.8 1.8 0 0 1 1.4757-.2601l5.1962 1.3498c1.3342.3467 2.5725-.9356 2.1794-2.2543v.0002l-1.532-5.1397a1.796 1.796 0 0 1 .209-1.482v-.0002l2.8934-4.5194c.742-1.1591-.0945-2.7324-1.472-2.766l-5.368-.1303a1.8 1.8 0 0 1-1.3467-.6558L12.0862.6422c-.3827-.4654-.9342-.6678-1.4718-.6396m5.7066 10.4086c.4626-.0106.8762.3176.959.7872a.953.953 0 0 1-.773 1.1038.9528.9528 0 1 1-.186-1.891M8.6439 11.765a.953.953 0 0 1 .959.7873c.0913.5182-.2548 1.0123-.773 1.1038s-1.0125-.2547-1.1038-.7729c-.0914-.5182.2547-1.0124.773-1.1038a.96.96 0 0 1 .1448-.0144m4.928 1.3841a.486.486 0 0 1 .3397.15.485.485 0 0 1 .1339.3463 1.264 1.264 0 0 1-.3917.8853v.0001h-.0002a1.266 1.266 0 0 1-.9026.3488h-.0004a1.26 1.26 0 0 1-.4812-.1079 1.26 1.26 0 0 1-.4038-.284 1.27 1.27 0 0 1-.2642-.4168.485.485 0 0 1 .278-.6272.483.483 0 0 1 .371.009.485.485 0 0 1 .2561.2687.29.29 0 0 0 .0615.097v.0002a.3.3 0 0 0 .0938.0658v.0001h.0003a.295.295 0 0 0 .2252.0055l.0003-.0001a.292.292 0 0 0 .1628-.1553l.0002-.0002v-.0001a.29.29 0 0 0 .025-.1116.486.486 0 0 1 .15-.3395.485.485 0 0 1 .3463-.134z"/></svg>',
  },
  {
    name: 'Elixir',
    href: '/docs/elixir',
    colorClass: 'lang-icon-elixir',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M19.793 16.575c0 3.752-2.927 7.426-7.743 7.426-5.249 0-7.843-3.71-7.843-8.29 0-5.21 3.892-12.952 8-15.647a.397.397 0 0 1 .61.371 9.716 9.716 0 0 0 1.694 6.518c.522.795 1.092 1.478 1.763 2.352.94 1.227 1.637 1.906 2.644 3.842l.015.028a7.107 7.107 0 0 1 .86 3.4z"/></svg>',
  },
  {
    name: 'MoonBit',
    href: '/docs/moonbit',
    colorClass: 'lang-icon-moonbit',
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>',
  },
]

const footerLinks = {
  documentation: [
    { name: 'Quickstart', href: '/docs/setup' },
    { name: 'Language Reference', href: '/docs/language-reference' },
    { name: 'Serialization', href: '/docs/serialization' },
    { name: 'Schema Evolution', href: '/docs/schema-evolution' },
  ],
  languages: [
    { name: 'C++', href: '/docs/cpp' },
    { name: 'C#', href: '/docs/csharp' },
    { name: 'Dart', href: '/docs/dart' },
    { name: 'Elixir', href: '/docs/elixir' },
    { name: 'Gleam', href: '/docs/gleam' },
    { name: 'Go', href: '/docs/go' },
    { name: 'Java', href: '/docs/java' },
    { name: 'Kotlin', href: '/docs/kotlin' },
    { name: 'MoonBit', href: '/docs/moonbit' },
    { name: 'Python', href: '/docs/python' },
    { name: 'Rust', href: '/docs/rust' },
    { name: 'Swift', href: '/docs/swift' },
    { name: 'TypeScript', href: '/docs/typescript' },
    { name: 'Zig', href: '/docs/zig' },
  ],
  resources: [
    {
      name: 'Why I Built Skir (Blog)',
      href: 'https://medium.com/@gepheum/i-spent-15-years-with-protobuf-then-i-built-skir-9cf61cc65631',
      external: true,
    },
    { name: 'Converter App', href: '/converter.html', external: true },
    { name: 'GitHub', href: 'https://github.com/gepheum/skir', external: true },
    { name: 'Discord', href: 'https://discord.gg/FsKrGwJ9AP', external: true },
  ],
}
</script>

<template>
  <div class="skir-home">
    <!-- Hero Section -->
    <section class="skir-hero-section">
      <div class="skir-hero-glow" aria-hidden="true" />
      <div class="skir-container">
        <div class="skir-hero-inner">
          <a
            href="https://github.com/gepheum/skir"
            target="_blank"
            rel="noopener noreferrer"
            class="skir-version-pill"
          >
            <span class="skir-version-tag">v1.2</span>
            <span class="skir-version-motto">Types that travel.</span>
          </a>

          <h1 class="skir-hero-title">
            The single <span class="skir-brand-text">source of truth</span>
            <br />
            for your data types
          </h1>

          <p class="skir-hero-subtitle">
            Skir is a modern declarative schema language for data models and APIs.
            <br />
            Write once in a <code class="skir-inline-code">.skir</code> file - instantly generate
            clean, idiomatic, and fully type-safe code in TypeScript, Python, Java, Go, C++, and
            more languages.
          </p>

          <div class="skir-hero-actions">
            <a href="/docs/setup" class="skir-btn-primary">
              <span>Get Started</span>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M5 12h14" />
                <path d="m12 5 7 7-7 7" />
              </svg>
            </a>
            <QuickstartPill />
          </div>

          <div class="skir-hero-video">
            <HoverVideo src="/greet.mp4" maxWidth="900px" />
          </div>
        </div>
      </div>
    </section>

    <!-- Code Example Section -->
    <section class="skir-section">
      <div class="skir-container">
        <div class="skir-max-5xl">
          <div class="skir-section-header">
            <h2 class="skir-section-title">One schema, 10+ languages, zero headaches</h2>
            <p class="skir-section-subtitle">
              One YAML file. One command.
              <br />
              No manual reruns: watch mode refreshes generated code on every change.
              <br />
              Zero-install compiler (<code class="skir-inline-code">npx</code>), easy to integrate
              into any workflow.
            </p>
          </div>

          <slot name="code-example" />
        </div>
      </div>
    </section>

    <!-- LLMs Section -->
    <section class="skir-section">
      <div class="skir-container">
        <div class="skir-max-3xl skir-text-center">
          <h2 class="skir-section-title-md">LLMs make 10x fewer mistakes with strong types</h2>
          <p class="skir-section-subtitle">
            Skir gives your AI coding tools the type information they crave.
            <br />
            A 2025
            <a
              href="https://arxiv.org/pdf/2504.09246?"
              target="_blank"
              rel="noopener noreferrer"
              class="skir-underline-link"
              >study</a
            >
            reports that nearly 94% of common LLM coding errors are type-related, which helps
            explain why strong typing can drastically reduce mistakes.
            <br />
            Don't believe it?
            <a
              href="https://gemini.google.com/share/ea387c7e27e9"
              target="_blank"
              rel="noopener noreferrer"
              class="skir-underline-link"
              >Ask AI</a
            >.
          </p>
        </div>
      </div>
    </section>

    <!-- Schema Evolution Section -->
    <section class="skir-section">
      <div class="skir-container">
        <div class="skir-max-5xl skir-text-center">
          <h2 class="skir-section-title">Serialize now, deserialize in 100 years</h2>
          <p class="skir-section-subtitle skir-mb-12">
            Modifying schemas in a long-lived or distributed system is risky—one wrong move can
            break clients or make it impossible to deserialize old data.
            <br />
            Skir has simple guidelines and built-in checks to evolve your schema safely.
          </p>

          <div class="home-split-images">
            <div class="home-image-box">
              <div class="home-image-label">Before</div>
              <img src="/shapes-before.png" alt="Schema before evolution changes" />
            </div>
            <div class="home-image-box">
              <div class="home-image-label">After</div>
              <img src="/shapes-after.png" alt="Schema after evolution changes" />
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- SkirRPC Section -->
    <section class="skir-section skir-section-alt">
      <div class="skir-container">
        <div class="skir-max-5xl skir-text-center">
          <h2 class="skir-section-title">End-to-end typesafety with SkirRPC</h2>
          <p class="skir-section-subtitle skir-mb-8">
            SkirRPC is a lightweight HTTP protocol for typesafe cross-service or frontend↔backend
            communication. It integrates with your existing web framework. Your client and server
            use the same generated method definitions, so contract mismatches are caught before
            runtime.
          </p>
          <HoverVideo src="/rpc-studio.mp4" maxWidth="900px" />
          <p class="skir-video-caption">
            Every SkirRPC service ships with a built-in Studio app for browsing and testing its
            methods.
          </p>
        </div>
      </div>
    </section>

    <!-- More Features Section -->
    <section class="skir-section">
      <div class="skir-container">
        <div class="skir-section-header">
          <h2 class="skir-section-title">More features</h2>
        </div>

        <div class="skir-features-grid">
          <div class="skir-feature-card">
            <div class="skir-feature-icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
              </svg>
            </div>
            <h3 class="skir-feature-title">Serialization to JSON or binary</h3>
            <p class="skir-feature-desc">
              Choose between dense JSON for web APIs and databases, readable JSON for debugging, or
              binary for raw performance.
            </p>
          </div>

          <div class="skir-feature-card">
            <div class="skir-feature-icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M16.5 9.4 7.55 4.24" />
                <path
                  d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"
                />
                <polyline points="3.29 7 12 12 20.71 7" />
                <line x1="12" x2="12" y1="22" y2="12" />
              </svg>
            </div>
            <h3 class="skir-feature-title">GitHub imports</h3>
            <p class="skir-feature-desc">
              Don't copy files. Import types directly from any GitHub repository. Share common data
              structures across projects.
            </p>
          </div>

          <div class="skir-feature-card">
            <div class="skir-feature-icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                width="24"
                height="24"
                fill="currentColor"
              >
                <path
                  d="M23.8346 11.7033l-1.0073-.6236a13.7268 13.7268 0 00-.0283-.2936l.8656-.8069a.3483.3483 0 00-.1154-.578l-1.1066-.414a8.4958 8.4958 0 00-.087-.2856l.6904-.9587a.3462.3462 0 00-.2257-.5446l-1.1663-.1894a9.3574 9.3574 0 00-.1407-.2622l.49-1.0761a.3437.3437 0 00-.0274-.3361.3486.3486 0 00-.3006-.154l-1.1845.0416a6.7444 6.7444 0 00-.1873-.2268l.2723-1.153a.3472.3472 0 00-.417-.4172l-1.1532.2724a14.0183 14.0183 0 00-.2278-.1873l.0415-1.1845a.3442.3442 0 00-.49-.328l-1.076.491c-.0872-.0476-.1742-.0952-.2623-.1407l-.1903-1.1673A.3483.3483 0 0016.256.955l-.9597.6905a8.4867 8.4867 0 00-.2855-.086l-.414-1.1066a.3483.3483 0 00-.5781-.1154l-.8069.8666a9.2936 9.2936 0 00-.2936-.0284L12.2946.1683a.3462.3462 0 00-.5892 0l-.6236 1.0073a13.7383 13.7383 0 00-.2936.0284L9.9803.3374a.3462.3462 0 00-.578.1154l-.4141 1.1065c-.0962.0274-.1903.0567-.2855.086L7.744.955a.3483.3483 0 00-.5447.2258L7.009 2.348a9.3574 9.3574 0 00-.2622.1407l-1.0762-.491a.3462.3462 0 00-.49.328l.0416 1.1845a7.9826 7.9826 0 00-.2278.1873L3.8413 3.425a.3472.3472 0 00-.4171.4171l.2713 1.1531c-.0628.075-.1255.1509-.1863.2268l-1.1845-.0415a.3462.3462 0 00-.328.49l.491 1.0761a9.167 9.167 0 00-.1407.2622l-1.1662.1894a.3483.3483 0 00-.2258.5446l.6904.9587a13.303 13.303 0 00-.087.2855l-1.1065.414a.3483.3483 0 00-.1155.5781l.8656.807a9.2936 9.2936 0 00-.0283.2935l-1.0073.6236a.3442.3442 0 000 .5892l1.0073.6236c.008.0982.0182.1964.0283.2936l-.8656.8079a.3462.3462 0 00.1155.578l1.1065.4141c.0273.0962.0567.1914.087.2855l-.6904.9587a.3452.3452 0 00.2268.5447l1.1662.1893c.0456.088.0922.1751.1408.2622l-.491 1.0762a.3462.3462 0 00.328.49l1.1834-.0415c.0618.0769.1235.1528.1873.2277l-.2713 1.1541a.3462.3462 0 00.4171.4161l1.153-.2713c.075.0638.151.1255.2279.1863l-.0415 1.1845a.3442.3442 0 00.49.327l1.0761-.49c.087.0486.1741.0951.2622.1407l.1903 1.1662a.3483.3483 0 00.5447.2268l.9587-.6904a9.299 9.299 0 00.2855.087l.414 1.1066a.3452.3452 0 00.5781.1154l.8079-.8656c.0972.0111.1954.0203.2936.0294l.6236 1.0073a.3472.3472 0 00.5892 0l.6236-1.0073c.0982-.0091.1964-.0183.2936-.0294l.8069.8656a.3483.3483 0 00.578-.1154l.4141-1.1066a8.4626 8.4626 0 00.2855-.087l.9587.6904a.3452.3452 0 00.5447-.2268l.1903-1.1662c.088-.0456.1751-.0931.2622-.1407l1.0762.49a.3472.3472 0 00.49-.327l-.0415-1.1845a6.7267 6.7267 0 00.2267-.1863l1.1531.2713a.3472.3472 0 00.4171-.416l-.2713-1.1542c.0628-.0749.1255-.1508.1863-.2278l1.1845.0415a.3442.3442 0 00.328-.49l-.49-1.076c.0475-.0872.0951-.1742.1407-.2623l1.1662-.1893a.3483.3483 0 00.2258-.5447l-.6904-.9587.087-.2855 1.1066-.414a.3462.3462 0 00.1154-.5781l-.8656-.8079c.0101-.0972.0202-.1954.0283-.2936l1.0073-.6236a.3442.3442 0 000-.5892zm-6.7413 8.3551a.7138.7138 0 01.2986-1.396.714.714 0 11-.2997 1.396zm-.3422-2.3142a.649.649 0 00-.7715.5l-.3573 1.6685c-1.1035.501-2.3285.7795-3.6193.7795a8.7368 8.7368 0 01-3.6951-.814l-.3574-1.6684a.648.648 0 00-.7714-.499l-1.473.3158a8.7216 8.7216 0 01-.7613-.898h7.1676c.081 0 .1356-.0141.1356-.088v-2.536c0-.074-.0536-.0881-.1356-.0881h-2.0966v-1.6077h2.2677c.2065 0 1.1065.0587 1.394 1.2088.0901.3533.2875 1.5044.4232 1.8729.1346.413.6833 1.2381 1.2685 1.2381h3.5716a.7492.7492 0 00.1296-.0131 8.7874 8.7874 0 01-.8119.9526zM6.8369 20.024a.714.714 0 11-.2997-1.396.714.714 0 01.2997 1.396zM4.1177 8.9972a.7137.7137 0 11-1.304.5791.7137.7137 0 011.304-.579zm-.8352 1.9813l1.5347-.6824a.65.65 0 00.33-.8585l-.3158-.7147h1.2432v5.6025H3.5669a8.7753 8.7753 0 01-.2834-3.348zm6.7343-.5437V8.7836h2.9601c.153 0 1.0792.1772 1.0792.8697 0 .575-.7107.7815-1.2948.7815zm10.7574 1.4862c0 .2187-.008.4363-.0243.651h-.9c-.09 0-.1265.0586-.1265.1477v.413c0 .973-.5487 1.1846-1.0296 1.2382-.4576.0517-.9648-.1913-1.0275-.4717-.2704-1.5186-.7198-1.8436-1.4305-2.4034.8817-.5599 1.799-1.386 1.799-2.4915 0-1.1936-.819-1.9458-1.3769-2.3153-.7825-.5163-1.6491-.6195-1.883-.6195H5.4682a8.7651 8.7651 0 014.907-2.7699l1.0974 1.151a.648.648 0 00.9182.0213l1.227-1.1743a8.7753 8.7753 0 016.0044 4.2762l-.8403 1.8982a.652.652 0 00.33.8585l1.6178.7188c.0283.2875.0425.577.0425.8717zm-9.3006-9.5993a.7128.7128 0 11.984 1.0316.7137.7137 0 01-.984-1.0316zm8.3389 6.71a.7107.7107 0 01.9395-.3625.7137.7137 0 11-.9405.3635z"
                />
              </svg>
            </div>
            <h3 class="skir-feature-title">Polymorphism done right</h3>
            <p class="skir-feature-desc">
              Model polymorphism clearly with sum types. Skir lets you attach typed data payloads to
              individual <code>enum</code> variants.
            </p>
          </div>

          <div class="skir-feature-card">
            <div class="skir-feature-icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M16.5 9.4 7.55 4.24" />
                <path
                  d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"
                />
                <polyline points="3.29 7 12 12 20.71 7" />
                <line x1="12" x2="12" y1="22" y2="12" />
              </svg>
            </div>
            <h3 class="skir-feature-title">Prioritizes immutability</h3>
            <p class="skir-feature-desc">
              Skir generates deeply immutable types with all fields required at construction time in
              target languages where that is idiomatic.
            </p>
          </div>

          <div class="skir-feature-card">
            <div class="skir-feature-icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M16.5 9.4 7.55 4.24" />
                <path
                  d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"
                />
                <polyline points="3.29 7 12 12 20.71 7" />
                <line x1="12" x2="12" y1="22" y2="12" />
              </svg>
            </div>
            <h3 class="skir-feature-title">Constants you can share</h3>
            <p class="skir-feature-desc">
              Define constants in your <code>.skir</code> files. They ship in generated code, so
              services share the same values without runtime config reads.
            </p>
          </div>

          <div class="skir-feature-card">
            <div class="skir-feature-icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
              </svg>
            </div>
            <h3 class="skir-feature-title">Serializable schemas</h3>
            <p class="skir-feature-desc">
              Skir schemas can be serialized and deserialized as JSON. This enables generic tools,
              like the Studio app, to understand schema structure.
            </p>
          </div>

          <div class="skir-feature-card">
            <div class="skir-feature-icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M16.5 9.4 7.55 4.24" />
                <path
                  d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"
                />
                <polyline points="3.29 7 12 12 20.71 7" />
                <line x1="12" x2="12" y1="22" y2="12" />
              </svg>
            </div>
            <h3 class="skir-feature-title">Key-indexed arrays</h3>
            <p class="skir-feature-desc">
              The array type allows you to specify a key field, e.g. <code>[User|user_id]</code>. On
              the wire, this is just like an array, but the generated code will give you fast
              key-based lookups.
            </p>
          </div>

          <div class="skir-feature-card">
            <div class="skir-feature-icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <polyline points="4 17 10 11 4 5" />
                <line x1="12" x2="20" y1="19" y2="19" />
              </svg>
            </div>
            <h3 class="skir-feature-title">First-class IDE support</h3>
            <p class="skir-feature-desc">
              A powerful
              <a
                href="https://marketplace.visualstudio.com/items?itemName=gepheum.skir-lang"
                target="_blank"
                rel="noopener noreferrer"
                class="skir-underline-link"
                >VS Code extension</a
              >
              (also on
              <a
                href="https://open-vsx.org/extension/gepheum/skir-lang"
                target="_blank"
                rel="noopener noreferrer"
                class="skir-underline-link"
                >Open VSX</a
              >) and
              <a
                href="https://github.com/gepheum/skir/tree/main/packages/language-server"
                target="_blank"
                rel="noopener noreferrer"
                class="skir-underline-link"
                >LSP</a
              >
              with all the features you need. Real-time validation, code completion, automatic code
              formatting and more.
            </p>
          </div>

          <div class="skir-feature-card">
            <div class="skir-feature-icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <polyline points="4 17 10 11 4 5" />
                <line x1="12" x2="20" y1="19" y2="19" />
              </svg>
            </div>
            <h3 class="skir-feature-title">Easy to extend</h3>
            <p class="skir-feature-desc">
              Code generators are regular NPM modules, so you can add custom ones without hacking
              the compiler.
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- Language Support Section -->
    <section class="skir-section">
      <div class="skir-container">
        <div class="skir-section-header">
          <h2 class="skir-section-title">Supported languages</h2>
          <p class="skir-section-subtitle">
            Generate production-ready code for all major programming languages.
          </p>
        </div>

        <div class="skir-languages-grid">
          <a v-for="lang in languages" :key="lang.name" :href="lang.href" class="skir-lang-card">
            <div class="skir-lang-card-left">
              <div class="skir-lang-icon" :class="lang.colorClass" v-html="lang.svg" />
              <span class="skir-lang-name">{{ lang.name }}</span>
            </div>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="skir-lang-arrow"
            >
              <path d="M5 12h14" />
              <path d="m12 5 7 7-7 7" />
            </svg>
          </a>
        </div>
      </div>
    </section>

    <!-- Ready to get started CTA Section -->
    <section class="skir-section">
      <div class="skir-container">
        <div class="skir-max-3xl skir-text-center">
          <h2 class="skir-section-title">Ready to get started?</h2>
          <p class="skir-section-subtitle skir-mb-8">
            Set up your first Skir project in minutes. Manage your entire project configuration from
            a single YAML file.
          </p>
          <div class="skir-hero-actions">
            <a href="/docs" class="skir-btn-primary">
              <span>Read the Docs</span>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M5 12h14" />
                <path d="m12 5 7 7-7 7" />
              </svg>
            </a>
          </div>
        </div>
      </div>
    </section>

    <!-- Discord Section -->
    <section class="skir-discord-section">
      <div class="skir-container">
        <div class="skir-max-2xl skir-text-center">
          <h2 class="skir-discord-title">Join our Discord</h2>
          <p class="skir-discord-subtitle">
            Ask questions, share feedback, and get help from the community.
          </p>
          <a
            href="https://discord.gg/FsKrGwJ9AP"
            target="_blank"
            rel="noopener noreferrer"
            class="skir-btn-outline"
          >
            <span>Join Discord</span>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M5 12h14" />
              <path d="m12 5 7 7-7 7" />
            </svg>
          </a>
        </div>
      </div>
    </section>

    <!-- Original 4-Column Footer -->
    <footer class="skir-footer">
      <div class="skir-container">
        <div class="skir-footer-grid">
          <div class="skir-footer-brand">
            <a href="/" class="skir-footer-logo-link">
              <img src="/icon.svg" alt="Skir" width="36" height="36" class="skir-footer-logo" />
              <span class="skir-footer-brand-name">Skir</span>
            </a>
            <p class="skir-footer-motto">Types that travel.</p>
            <a
              href="https://github.com/gepheum/skir"
              target="_blank"
              rel="noopener noreferrer"
              class="skir-footer-gh-link"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4"
                />
                <path d="M9 18c-4.51 2-5-2-7-2" />
              </svg>
              <span>gepheum/skir</span>
            </a>
          </div>

          <div>
            <h3 class="skir-footer-heading">Documentation</h3>
            <ul class="skir-footer-list">
              <li v-for="link in footerLinks.documentation" :key="link.name">
                <a :href="link.href" class="skir-footer-link">{{ link.name }}</a>
              </li>
            </ul>
          </div>

          <div>
            <h3 class="skir-footer-heading">Languages</h3>
            <ul class="skir-footer-list">
              <li v-for="link in footerLinks.languages" :key="link.name">
                <a :href="link.href" class="skir-footer-link">{{ link.name }}</a>
              </li>
            </ul>
          </div>

          <div>
            <h3 class="skir-footer-heading">Resources</h3>
            <ul class="skir-footer-list">
              <li v-for="link in footerLinks.resources" :key="link.name">
                <a
                  :href="link.href"
                  :target="link.external ? '_blank' : undefined"
                  :rel="link.external ? 'noopener noreferrer' : undefined"
                  class="skir-footer-link"
                >
                  {{ link.name }}
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div class="skir-footer-bottom">
          <p>Released under the MIT License. Copyright 2024-present Gepheum.</p>
        </div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.skir-home {
  width: 100%;
  color: var(--vp-c-text-1);
}

.skir-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 20px;
}

.skir-max-5xl {
  max-width: 1024px;
  margin: 0 auto;
}

.skir-max-3xl {
  max-width: 768px;
  margin: 0 auto;
}

.skir-max-2xl {
  max-width: 672px;
  margin: 0 auto;
}

.skir-text-center {
  text-align: center;
}

.skir-mb-8 {
  margin-bottom: 2rem !important;
}

.skir-mb-12 {
  margin-bottom: 3rem !important;
}

/* Hero */
.skir-hero-section {
  position: relative;
  overflow: hidden;
  padding: 80px 0 88px;
}

@media (min-width: 768px) {
  .skir-hero-section {
    padding: 96px 0 108px;
  }
}

.skir-hero-glow {
  position: absolute;
  top: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 840px;
  height: 520px;
  border-radius: 9999px;
  background: radial-gradient(circle, rgba(12, 200, 193, 0.14) 0%, rgba(1, 93, 103, 0) 70%);
  filter: blur(80px);
  pointer-events: none;
  z-index: 0;
}

.skir-hero-inner {
  position: relative;
  z-index: 1;
  max-width: 896px;
  margin: 0 auto;
  text-align: center;
}

.skir-version-pill {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  margin-bottom: 32px;
  border-radius: 9999px;
  background-color: var(--vp-c-bg-soft);
  border: 1px solid var(--vp-c-divider);
  font-size: 14px;
  text-decoration: none;
  transition: border-color 0.2s;
}

.skir-version-pill:hover {
  border-color: var(--vp-c-brand-1);
}

.skir-version-tag {
  color: var(--vp-c-brand-1);
  font-weight: 600;
}

.skir-version-motto {
  color: var(--vp-c-text-2);
}

.skir-hero-title {
  margin: 0 0 24px;
  font-size: 34px;
  line-height: 1.15;
  font-weight: 700;
  letter-spacing: -0.025em;
  color: var(--vp-c-text-1);
}

@media (min-width: 768px) {
  .skir-hero-title {
    font-size: 52px;
  }
}

@media (min-width: 1024px) {
  .skir-hero-title {
    font-size: 60px;
  }
}

.skir-brand-text {
  color: var(--vp-c-brand-1);
}

.skir-hero-subtitle {
  max-width: 672px;
  margin: 0 auto 40px;
  font-size: 18px;
  line-height: 1.65;
  color: var(--vp-c-text-2);
}

@media (min-width: 768px) {
  .skir-hero-subtitle {
    font-size: 20px;
  }
}

.skir-inline-code {
  font-family: var(--vp-font-family-mono);
  color: var(--vp-c-brand-1);
  background: transparent;
  padding: 0;
  font-size: 0.95em;
}

.skir-hero-actions {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  margin-bottom: 48px;
}

@media (min-width: 640px) {
  .skir-hero-actions {
    flex-direction: row;
  }
}

.skir-btn-primary {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  height: 44px;
  padding: 0 24px;
  border-radius: 9999px;
  background-color: var(--vp-button-brand-bg);
  color: var(--vp-button-brand-text) !important;
  font-size: 15px;
  font-weight: 600;
  text-decoration: none !important;
  transition: background-color 0.2s;
}

.skir-btn-primary:hover {
  background-color: var(--vp-button-brand-hover-bg);
}

.skir-btn-outline {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  height: 40px;
  padding: 0 24px;
  border-radius: 9999px;
  border: 1px solid var(--vp-c-divider);
  background-color: var(--vp-c-bg);
  color: var(--vp-c-text-1) !important;
  font-size: 14px;
  font-weight: 500;
  text-decoration: none !important;
  transition:
    border-color 0.2s,
    background-color 0.2s;
}

.skir-btn-outline:hover {
  border-color: var(--vp-c-brand-1);
  background-color: var(--vp-c-bg-soft);
}

.skir-hero-video {
  max-width: 1000px;
  margin: 0 auto;
}

/* Sections */
.skir-section {
  border-top: 1px solid var(--vp-c-divider);
  padding: 56px 0;
}

@media (min-width: 768px) {
  .skir-section {
    padding: 80px 0;
  }
}

.skir-section-alt {
  background-color: var(--vp-c-bg-soft);
}

.skir-section-header {
  text-align: center;
  margin-bottom: 48px;
}

.skir-section-title {
  margin: 0 0 16px;
  font-size: 30px;
  line-height: 1.2;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--vp-c-text-1);
  border: none;
  padding: 0;
}

@media (min-width: 768px) {
  .skir-section-title {
    font-size: 36px;
  }
}

.skir-section-title-md {
  margin: 0 0 16px;
  font-size: 24px;
  line-height: 1.25;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--vp-c-text-1);
  border: none;
  padding: 0;
}

@media (min-width: 768px) {
  .skir-section-title-md {
    font-size: 30px;
  }
}

.skir-section-subtitle {
  max-width: 672px;
  margin: 0 auto;
  font-size: 18px;
  line-height: 1.65;
  color: var(--vp-c-text-2);
}

.skir-underline-link {
  color: inherit;
  text-decoration: underline;
  text-decoration-color: var(--vp-c-text-3);
  transition: color 0.2s;
}

.skir-underline-link:hover {
  color: var(--vp-c-text-1);
}

.skir-video-caption {
  margin-top: 16px;
  text-align: center;
  font-size: 14px;
  color: var(--vp-c-text-2);
}

/* Feature Cards Grid */
.skir-features-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 24px;
  max-width: 1152px;
  margin: 0 auto;
}

@media (min-width: 768px) {
  .skir-features-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

.skir-feature-card {
  padding: 24px;
  border-radius: 12px;
  background-color: var(--vp-c-bg-soft);
  border: 1px solid var(--vp-c-divider);
  transition: border-color 0.2s;
}

.skir-feature-card:hover {
  border-color: var(--vp-c-brand-1);
}

.skir-feature-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  margin-bottom: 16px;
  border-radius: 12px;
  background-color: var(--vp-c-brand-soft);
  color: var(--vp-c-brand-1);
}

.skir-feature-title {
  margin: 0 0 8px;
  font-size: 18px;
  font-weight: 600;
  color: var(--vp-c-text-1);
}

.skir-feature-desc {
  margin: 0;
  font-size: 14px;
  line-height: 1.6;
  color: var(--vp-c-text-2);
}

.skir-feature-desc code {
  font-family: var(--vp-font-family-mono);
  font-size: 12.5px;
  padding: 2px 5px;
  border-radius: 4px;
  background-color: var(--vp-c-default-soft);
  color: var(--vp-c-text-1);
}

/* Language Cards Grid */
.skir-languages-grid {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 16px;
  max-width: 896px;
  margin: 0 auto;
}

.skir-lang-card {
  width: 100%;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  border-radius: 12px;
  background-color: var(--vp-c-bg-soft);
  border: 1px solid var(--vp-c-divider);
  text-decoration: none !important;
  color: var(--vp-c-text-1) !important;
  transition:
    border-color 0.2s,
    background-color 0.2s;
}

@media (min-width: 640px) {
  .skir-lang-card {
    width: calc((100% - 16px) / 2);
  }
}

@media (min-width: 1024px) {
  .skir-lang-card {
    width: calc((100% - 32px) / 3);
  }
}

.skir-lang-card:hover {
  border-color: var(--vp-c-brand-1);
}

.skir-lang-card-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.skir-lang-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 8px;
  background-color: var(--vp-c-bg);
  font-family: var(--vp-font-family-mono);
  font-size: 14px;
  font-weight: 700;
}

.skir-lang-name {
  font-weight: 500;
  font-size: 15px;
}

.skir-lang-arrow {
  color: var(--vp-c-text-3);
  transition:
    color 0.2s,
    transform 0.2s;
}

.skir-lang-card:hover .skir-lang-arrow {
  color: var(--vp-c-brand-1);
  transform: translateX(2px);
}

/* Discord Section */
.skir-discord-section {
  border-top: 1px solid var(--vp-c-divider);
  background-color: var(--vp-c-bg-soft);
  padding: 48px 0;
}

.skir-discord-title {
  margin: 0 0 12px;
  font-size: 24px;
  font-weight: 600;
  color: var(--vp-c-text-1);
}

@media (min-width: 768px) {
  .skir-discord-title {
    font-size: 30px;
  }
}

.skir-discord-subtitle {
  margin: 0 0 24px;
  font-size: 16px;
  color: var(--vp-c-text-2);
}

/* Footer */
.skir-footer {
  border-top: 1px solid var(--vp-c-divider);
  background-color: var(--vp-c-bg-alt);
  padding: 48px 0;
}

.skir-footer-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 32px;
}

@media (min-width: 768px) {
  .skir-footer-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

.skir-footer-brand {
  grid-column: span 2;
}

@media (min-width: 768px) {
  .skir-footer-brand {
    grid-column: span 1;
  }
}

.skir-footer-logo-link {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
  text-decoration: none !important;
  color: var(--vp-c-text-1) !important;
}

.skir-footer-brand-name {
  font-size: 20px;
  font-weight: 700;
}

.skir-footer-motto {
  margin: 0 0 16px;
  font-size: 14px;
  color: var(--vp-c-text-2);
}

.skir-footer-gh-link {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: var(--vp-c-text-2);
  text-decoration: none;
  transition: color 0.2s;
}

.skir-footer-gh-link:hover {
  color: var(--vp-c-text-1);
}

.skir-footer-heading {
  margin: 0 0 16px;
  font-size: 15px;
  font-weight: 600;
  color: var(--vp-c-text-1);
}

.skir-footer-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.skir-footer-link {
  font-size: 14px;
  color: var(--vp-c-text-2);
  text-decoration: none;
  transition: color 0.2s;
}

.skir-footer-link:hover {
  color: var(--vp-c-text-1);
}

.skir-footer-bottom {
  margin-top: 48px;
  padding-top: 32px;
  border-top: 1px solid var(--vp-c-divider);
  text-align: center;
  font-size: 14px;
  color: var(--vp-c-text-2);
}

.skir-footer-bottom p {
  margin: 0;
}

.skir-lang-icon :deep(svg) {
  width: 24px;
  height: 24px;
}
.lang-icon-ts {
  color: #3178c6;
}
.lang-icon-py {
  color: #3776ab;
}
.lang-icon-java {
  color: #e76f00;
}
.lang-icon-csharp {
  color: #239120;
}
.lang-icon-cpp {
  color: #00599c;
}
.lang-icon-go {
  color: #00add8;
}
.lang-icon-kotlin {
  color: #7f52ff;
}
.lang-icon-dart {
  color: #0175c2;
}
.lang-icon-swift {
  color: #f05138;
}
.lang-icon-rust {
  color: #000000;
}
.dark .lang-icon-rust {
  color: #dea584;
}
.lang-icon-zig {
  color: #f7a41d;
}
.lang-icon-gleam {
  color: #ffaff3;
}
.lang-icon-elixir {
  color: #4b275f;
}
.dark .lang-icon-elixir {
  color: #b99acd;
}
.lang-icon-moonbit {
  color: #f5c84b;
}
</style>
