#pragma once

#if defined _WIN32 || defined __CYGWIN__
#ifdef __GNUC__
#define HA_SYMBOL_EXPORT __attribute__((dllexport))
#define HA_SYMBOL_IMPORT __attribute__((dllimport))
#else // __GNUC__
#define HA_SYMBOL_EXPORT __declspec(dllexport)
#define HA_SYMBOL_IMPORT __declspec(dllimport)
#endif // __GNUC__
#else  // _WIN32
#define HA_SYMBOL_EXPORT __attribute__((visibility("default")))
#define HA_SYMBOL_IMPORT
#endif // _WIN32

// TODO: think about just using WINDOWS_EXPORT_ALL_SYMBOLS in cmake instead of manually annotating what to export from the executable

#ifndef HAPI
#define HAPI HA_SYMBOL_IMPORT
#endif // HAPI
