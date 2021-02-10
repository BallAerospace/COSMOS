module.exports = {
  preset: '@vue/cli-plugin-unit-jest',
  transformIgnorePatterns: [
    'node_modules/(?!(@astrouxds' + '|lit-element' + '|lit-html' + ')/)',
  ],
  setupFiles: ['<rootDir>/tests/unit/setup.js'],
}
