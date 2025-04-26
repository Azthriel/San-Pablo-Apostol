
// VARIABLES \\

//*-Estado de app-*\\
const bool xProfileMode = bool.fromEnvironment('dart.vm.profile');
const bool xReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool xDebugMode = !xProfileMode && !xReleaseMode;
//*-Estado de app-*\\

// FUNCIONES \\

void printLog(var text) {
  if (xDebugMode) {
    // ignore: avoid_print
    print('PrintData: $text');
  }
}

// CLASES \\

class FlavorSelection {
  String flavor;
  String size;
  String type;
  FlavorSelection({
    this.flavor = 'Membrillo',
    this.size = 'Docena',
    this.type = 'Tradicional',
  });
}
