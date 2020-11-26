import Vue from 'vue'
import Router from 'vue-router'

Vue.use(Router)

export default new Router({
  mode: 'history',
  base: process.env.BASE_URL,
  routes: [
    {
      path: '/cmd-tlm-server',
      alias: '/',
      name: 'CmdTlmServer',
      component: () => import('./views/CmdTlmServerView.vue'),
      meta: {
        title: 'Command and Telemetry Server',
        icon: 'mdi-server-network',
      },
    },
    {
      path: '/limits-monitor',
      name: 'LimitsMonitor',
      component: () => import('./views/LimitsMonitorView.vue'),
      meta: { title: 'Limits Monitor', icon: 'mdi-alert' },
    },
    {
      path: '/command-sender/:target?/:packet?',
      name: 'CommandSender',
      component: () => import('./views/CommandSenderView.vue'),
      meta: { title: 'Command Sender', icon: 'mdi-satellite-uplink' },
    },
    {
      path: '/script-runner/:id?',
      name: 'ScriptRunner',
      component: () => import('./views/ScriptRunnerView.vue'),
      meta: { title: 'Script Runner', icon: 'mdi-run-fast' },
    },
    {
      path: '/packet-viewer/:target?/:packet?',
      name: 'PackerViewer',
      component: () => import('./views/PacketViewerView.vue'),
      meta: { title: 'Packer Viewer', icon: 'mdi-format-list-bulleted' },
    },
    {
      path: '/telemetry-viewer',
      name: 'TlmViewer',
      component: () => import('./views/TlmViewerView.vue'),
      meta: { title: 'Telemetry Viewer', icon: 'mdi-monitor-dashboard' },
    },
    // {
    //   path: '/data-viewer',
    //   name: 'DataViewer',
    //   component: () => import('./views/DataViewerView.vue'),
    //   meta: { title: 'Data Viewer', icon: 'mdi-view-split-horizontal' }
    // },
    {
      path: '/telemetry-grapher',
      name: 'TlmGrapher',
      component: () => import('./views/TlmGrapherView.vue'),
      meta: { title: 'Telemetry Grapher', icon: 'mdi-chart-line' },
    },
    {
      path: '/data-extractor',
      name: 'Data Extractor',
      component: () => import('./views/DataExtractorView.vue'),
      meta: { title: 'Data Extractor', icon: 'mdi-archive-arrow-down' },
    },
    {
      path: '/admin',
      name: 'Admin',
      component: () => import('./views/AdminView.vue'),
      children: [
        {
          component: () => import('./tools/CosmosAdmin/PluginsTab'),
          path: '',
        },
        {
          component: () => import('./tools/CosmosAdmin/PluginsTab'),
          path: 'plugins',
        },
        {
          component: () => import('./tools/CosmosAdmin/TargetsTab'),
          path: 'targets',
        },
        {
          component: () => import('./tools/CosmosAdmin/InterfacesTab'),
          path: 'interfaces',
        },
        {
          component: () => import('./tools/CosmosAdmin/RoutersTab'),
          path: 'routers',
        },
        {
          component: () => import('./tools/CosmosAdmin/MicroservicesTab'),
          path: 'microservices',
        },
        {
          component: () => import('./tools/CosmosAdmin/ToolsTab'),
          path: 'tools',
        },
        {
          component: () => import('./tools/CosmosAdmin/GemsTab'),
          path: 'gems',
        },
        {
          component: () => import('./tools/CosmosAdmin/ScopesTab'),
          path: 'scopes',
        },
      ],
    },
    // TODO: Create NotFoundComponent since we're doing history browser mode
    // See: https://router.vuejs.org/guide/essentials/history-mode.html#example-server-configurations
    // {
    //   path: '*',
    //   component: NotFoundComponent
    // }
  ],
})
