#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Register the window class.
  WNDCLASSEXW wc = {0};
  wc.cbSize = sizeof(WNDCLASSEX);
  wc.lpfnWndProc = DefWindowProc;
  wc.hInstance = instance;
  wc.lpszClassName = L"FLUTTER_RUNNER_WIN32_WINDOW";
  RegisterClassExW(&wc);

  // Register custom URL scheme
  HKEY hKey;
  const wchar_t* urlScheme = L"sonnet";
  const wchar_t* urlProtocol = L"URL:Sonnet Protocol";
  
  // Get the path to the executable
  wchar_t exePath[MAX_PATH];
  GetModuleFileNameW(NULL, exePath, MAX_PATH);
  
  // Create the command string with quotes
  wchar_t command[MAX_PATH + 10];
  swprintf(command, MAX_PATH + 10, L"\"%s\" \"%%1\"", exePath);

  if (RegCreateKeyExW(HKEY_CLASSES_ROOT, urlScheme, 0, NULL, REG_OPTION_NON_VOLATILE,
                      KEY_WRITE, NULL, &hKey, NULL) == ERROR_SUCCESS) {
    RegSetValueExW(hKey, NULL, 0, REG_SZ, (BYTE*)urlProtocol,
                   static_cast<DWORD>((wcslen(urlProtocol) + 1) * sizeof(wchar_t)));
    RegSetValueExW(hKey, L"URL Protocol", 0, REG_SZ, (BYTE*)L"",
                   static_cast<DWORD>(sizeof(wchar_t)));

    HKEY hKeyDefaultIcon;
    if (RegCreateKeyExW(hKey, L"DefaultIcon", 0, NULL,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL,
                        &hKeyDefaultIcon, NULL) == ERROR_SUCCESS) {
      RegSetValueExW(hKeyDefaultIcon, NULL, 0, REG_SZ,
                     (BYTE*)exePath,
                     static_cast<DWORD>((wcslen(exePath) + 1) * sizeof(wchar_t)));
      RegCloseKey(hKeyDefaultIcon);
    }

    HKEY hKeyCommand;
    if (RegCreateKeyExW(hKey, L"shell\\open\\command", 0, NULL,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL,
                        &hKeyCommand, NULL) == ERROR_SUCCESS) {
      RegSetValueExW(hKeyCommand, NULL, 0, REG_SZ, (BYTE*)command,
                     static_cast<DWORD>((wcslen(command) + 1) * sizeof(wchar_t)));
      RegCloseKey(hKeyCommand);
    }

    RegCloseKey(hKey);
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"sonnet", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
