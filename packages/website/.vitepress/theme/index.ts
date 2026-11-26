import DefaultTheme from 'vitepress/theme'
import './custom.css'
import HomePage from './HomePage.vue'
import HoverVideo from './HoverVideo.vue'
import QuickstartPill from './QuickstartPill.vue'
import SplitCodeExample from './SplitCodeExample.vue'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('HomePage', HomePage)
    app.component('QuickstartPill', QuickstartPill)
    app.component('SplitCodeExample', SplitCodeExample)
    app.component('HoverVideo', HoverVideo)
  },
}
