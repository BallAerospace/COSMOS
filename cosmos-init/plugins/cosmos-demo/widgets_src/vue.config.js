const path = require("path");

module.exports = {
  css: {
    extract: false,
  },
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  outputDir: path.resolve(__dirname, "../tools/widgets")
};