# cache this for use inside of the function
set(CURRENT_LIST_DIR_CACHED ${CMAKE_CURRENT_LIST_DIR})

# implementation of add_mix_dirs
macro(add_mix_dir_impl result rec trim dirs_in additional_ext)
    set(dirs "${dirs_in}")
    
    # handle the "" and "." cases
    if("${dirs}" STREQUAL "" OR "${dirs}" STREQUAL ".")
        set(dirs "./")
    endif()
    
    foreach(cur_dir ${dirs})
        # to circumvent some linux/cmake/path issues - barely made it work...
        if(cur_dir STREQUAL "./")
            set(cur_dir "")
        else()
            set(cur_dir "${cur_dir}/")
        endif()
        
        set(additional_file_extensions "${cur_dir}*.mix")
        foreach(ext ${additional_ext})
            list(APPEND additional_file_extensions "${cur_dir}*.${ext}")
        endforeach()
        
        # find all sources and add them to result
        FILE(GLOB found_sources RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
        # sources
            "${cur_dir}*.cpp"
            "${cur_dir}*.c"
        # headers
            "${cur_dir}*.h"
            "${cur_dir}*.hpp"
            "${cur_dir}*.inl"
            ${additional_file_extensions})
        list(APPEND ${result} ${found_sources})
        
        # set the proper filters
        ucm_trim_front_words("${cur_dir}" cur_dir "${trim}")
        # replacing forward slashes with back slashes so filters can be generated (back slash used in parsing...)
        STRING(REPLACE "/" "\\" FILTERS "${cur_dir}")
        SOURCE_GROUP("${FILTERS}" FILES ${found_sources})
        
        # set the filters as a property so it might be queried later
        set_source_files_properties(${found_sources} PROPERTIES FILTER_POP "${FILTERS}")
    endforeach()
    
    if(${rec})
        foreach(cur_dir ${dirs})
            ucm_dir_list("${cur_dir}" subdirs)
            foreach(subdir ${subdirs})
                add_mix_dir_impl(${result} ${rec} ${trim} "${cur_dir}/${subdir}" "${additional_ext}")
            endforeach()
        endforeach()
    endif()
endmacro()

# like ucm_add_dirs but optimized for this codebase - also adds the filters to .mix files as source properties
macro(add_mix_dirs)
    cmake_parse_arguments(ARG "RECURSIVE" "TO;FILTER_POP" "ADDITIONAL_EXT" ${ARGN})
    
    if(${ARG_TO} STREQUAL "")
        message(FATAL_ERROR "Need to pass TO and a variable name to add_mix_dirs()")
    endif()
    
    if("${ARG_FILTER_POP}" STREQUAL "")
        set(ARG_FILTER_POP 0)
    endif()
    
    add_mix_dir_impl(${ARG_TO} ${ARG_RECURSIVE} ${ARG_FILTER_POP} "${ARG_UNPARSED_ARGUMENTS}" "${ARG_ADDITIONAL_EXT}")
endmacro()

# for each .mix file in the target sources a header file will be generated and added to the target sources
function(mixify_target target)
    get_target_property(sources ${target} SOURCES)
	foreach(src ${sources})
        if("${src}" MATCHES \\.\(mix\)$)
            set(mix_file ${CMAKE_CURRENT_SOURCE_DIR}/${src})
            
            get_filename_component(mix_name_only ${mix_file} NAME_WE)
            string(REGEX REPLACE "\\.[^.]*$" "" mix_name_no_ext ${mix_file})
            
            set(gen_header ${mix_name_no_ext}_gen.h)
            
            add_custom_command(
                OUTPUT ${gen_header}
                MAIN_DEPENDENCY ${mix_file}
                COMMAND python ${CURRENT_LIST_DIR_CACHED}/../python/mix_file.py ${mix_file} ${gen_header}
                COMMENT "mixing ${mix_file}")
            
            target_sources(${target} PUBLIC ${gen_header})
            
            get_source_file_property(filters ${mix_file} FILTER_POP)
            SOURCE_GROUP("${filters}" FILES ${gen_header})
        endif()
    endforeach()
endfunction()

# add_precompiled_header
#
# Sets a precompiled header to be used for a given target.
# Calling this is essential for iOS applications.
# * msvc: Sets compile options to enable creation and use of a precompiled header.
#   You need to have a cpp file with the same name as the precompiled header, only
#   having .cpp extension. That file has to be added to the target prior to calling the macro.
# * gcc: Creates a precompiled header in a subdirectory in the build directory.
# * clang: todo
#
function(add_precompiled_header TARGET_NAME PRECOMPILED_HEADER)
    # my addition to the chobo pch macro - also changed it from a macro to a function (idk why but otherwise it didnt work...)
    if(NOT EXISTS "${CMAKE_CURRENT_BINARY_DIR}/precompiled_${TARGET_NAME}.h")
        file(WRITE  ${CMAKE_CURRENT_BINARY_DIR}/precompiled_${TARGET_NAME}.h "#include \"${PRECOMPILED_HEADER}\"\n")
        file(WRITE  ${CMAKE_CURRENT_BINARY_DIR}/precompiled_${TARGET_NAME}.cpp "#include \"precompiled_${TARGET_NAME}.h\"\n")
    endif()
    set(PRECOMPILED_HEADER ${CMAKE_CURRENT_BINARY_DIR}/precompiled_${TARGET_NAME}.h)
    set(PRECOMPILED_SOURCE ${CMAKE_CURRENT_BINARY_DIR}/precompiled_${TARGET_NAME}.cpp)
    target_sources(${TARGET_NAME} PRIVATE ${PRECOMPILED_SOURCE})
    SOURCE_GROUP("" FILES ${PRECOMPILED_SOURCE})

    # from here on goes the chobo
    get_filename_component(PRECOMPILED_HEADER_NAME ${PRECOMPILED_HEADER} NAME)

    if(MSVC)
        get_filename_component(PRECOMPILED_HEADER_INCLUDE ${PRECOMPILED_HEADER} NAME)
        get_filename_component(PRECOMPILED_HEADER_WE ${PRECOMPILED_HEADER} NAME_WE)

        if(CMAKE_GENERATOR STREQUAL "Ninja" OR CMAKE_GENERATOR STREQUAL "NMake Makefiles")
            set(PRECOMPILED_BINARY "${CMAKE_CURRENT_BINARY_DIR}/${PRECOMPILED_HEADER_WE}.pch")
        else()
            set(PRECOMPILED_BINARY "$(IntDir)/${PRECOMPILED_HEADER_WE}.pch")
        endif()

        get_target_property(SOURCE_FILES ${TARGET_NAME} SOURCES)
        set(SOURCE_FILE_FOUND FALSE)
        foreach(SOURCE_FILE ${SOURCE_FILES})
            set(PCH_COMPILE_FLAGS "")
            if(SOURCE_FILE MATCHES \\.\(cc|cxx|cpp\)$)
                if(SOURCE_FILE STREQUAL ${PRECOMPILED_SOURCE})
                    set_source_files_properties(
                        ${SOURCE_FILE}
                        PROPERTIES
                        COMPILE_FLAGS "/Yc\"${PRECOMPILED_HEADER_NAME}\" /Fp\"${PRECOMPILED_BINARY}\""
                        OBJECT_OUTPUTS "${PRECOMPILED_BINARY}")
                    set(SOURCE_FILE_FOUND TRUE)
                else()
                    set_source_files_properties(
                        ${SOURCE_FILE}
                        PROPERTIES
                        COMPILE_FLAGS "/Yu\"${PRECOMPILED_HEADER_NAME}\" /Fp\"${PRECOMPILED_BINARY}\" /FI\"${PRECOMPILED_HEADER_INCLUDE}\""
                        OBJECT_DEPENDS "${PRECOMPILED_BINARY}")
                endif()
            endif()
        endforeach()
        if(NOT SOURCE_FILE_FOUND)
            message(FATAL_ERROR "A source file for ${PRECOMPILED_HEADER} was not found. Required for MSVC builds.")
        endif(NOT SOURCE_FILE_FOUND)
    # elseif(CMAKE_COMPILER_IS_GNUCXX OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    elseif (APPLE AND NOT CMAKE_GENERATOR STREQUAL "Ninja")
        set_target_properties(
            ${TARGET_NAME}
            PROPERTIES
            XCODE_ATTRIBUTE_GCC_PREFIX_HEADER "${PRECOMPILED_HEADER}"
            XCODE_ATTRIBUTE_GCC_PRECOMPILE_PREFIX_HEADER "YES"
            )
    # elseif(CMAKE_COMPILER_IS_GNUCXX OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    else()
        # Create and set output directory.
        get_filename_component(PRECOMPILED_HEADER_NAME ${PRECOMPILED_HEADER} NAME)
        set(OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}/${PRECOMPILED_HEADER_NAME}.gch")
        make_directory(${OUTPUT_DIR})
        set(OUTPUT_NAME "${OUTPUT_DIR}/${PRECOMPILED_HEADER_NAME}.gch")

        # Gather compiler options, definitions, etc.
        string(TOUPPER "CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}" CXX_FLAGS)
        set(COMPILER_FLAGS "${${CXX_FLAGS}} ${CMAKE_CXX_FLAGS}")
        get_target_property(DIRECTORY_FLAGS ${TARGET_NAME} INCLUDE_DIRECTORIES)
        foreach(item ${DIRECTORY_FLAGS})
            list(APPEND COMPILER_FLAGS "-I${item}")
        endforeach(item)
        get_target_property(DIRECTORY_FLAGS ${TARGET_NAME} COMPILE_DEFINITIONS)
        foreach(item ${DIRECTORY_FLAGS})
            list(APPEND COMPILER_FLAGS "-D${item}")
        endforeach(item)

        # Add a custom target for building the precompiled header.
        separate_arguments(COMPILER_FLAGS)
        add_custom_command(
            OUTPUT ${OUTPUT_NAME}
            COMMAND ${CMAKE_CXX_COMPILER} ${COMPILER_FLAGS} -x c++-header -o ${OUTPUT_NAME} ${PRECOMPILED_HEADER}
            DEPENDS ${PRECOMPILED_HEADER})
        add_custom_target(${TARGET_NAME}_gch DEPENDS ${OUTPUT_NAME})
        add_dependencies(${TARGET_NAME} ${TARGET_NAME}_gch)
        set_target_properties(${TARGET_NAME} PROPERTIES COMPILE_FLAGS "-include ${PRECOMPILED_HEADER_NAME} -Winvalid-pch")
    endif()
endfunction()

# adds a plugin with supposedly .mix files in it - so it also mixifies it
function(add_plugin)
    cmake_parse_arguments(ARG "" "NAME" "LINK_TO" ${ARGN})
    
    if(NOT ${WITH_PLUGINS})
        list(APPEND PLUGIN_SOURCES ${ARG_UNPARSED_ARGUMENTS})
        set(PLUGIN_SOURCES ${PLUGIN_SOURCES} PARENT_SCOPE) # because we are a function
        # TODO: figure out what to do with the ARG_LINK_TO list - should somehow put stuff in a set of unique link libs...
        return()
    endif()
    
    add_library(${ARG_NAME} SHARED ${ARG_UNPARSED_ARGUMENTS})
    add_precompiled_header(${ARG_NAME} "${CMAKE_CURRENT_SOURCE_DIR}/precompiled.h")
    
    #et_target_properties(${ARG_NAME} PROPERTIES COTIRE_CXX_PREFIX_HEADER_INIT "${CMAKE_CURRENT_SOURCE_DIR}/precompiled.h")
    #set_target_properties(${ARG_NAME} PROPERTIES COTIRE_ADD_UNITY_BUILD FALSE)
    #cotire(${ARG_NAME})
            
    #ucm_add_target(NAME ${ARG_NAME} TYPE SHARED PCH_FILE "${CMAKE_CURRENT_SOURCE_DIR}/precompiled.h" SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/precompiled.cpp;${ARG_UNPARSED_ARGUMENTS}" UNITY_EXCLUDED "precompiled.cpp")
    
    set_target_properties(${ARG_NAME} PROPERTIES OUTPUT_NAME ${ARG_NAME}_plugin)
    set_target_properties(${ARG_NAME} PROPERTIES FOLDER "plugins")
    target_link_libraries(${ARG_NAME} game)
    
    foreach(lib "${ARG_LINK_TO}")
        target_link_libraries(${ARG_NAME} ${lib})
    endforeach()
    
    # for MSVC make the output name different, and copy to the expected name with a post-build step - this is needed
    # because the MSVC linker modifies a few times the .dll while finalizing it and file watchers go crazy!
    # but with a copy on post-build file watchers see just 1 notification for modification
    if(MSVC)
        set_target_properties(${ARG_NAME} PROPERTIES OUTPUT_NAME ${ARG_NAME}_plugin_msvc_orig)
        set(config_dir $<CONFIG>/)
        if(CMAKE_GENERATOR STREQUAL "Ninja")
            set(config_dir "")
        endif()
        add_custom_command(TARGET ${ARG_NAME} POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${ARG_NAME}>
            $<TARGET_PROPERTY:${ARG_NAME},LIBRARY_OUTPUT_DIRECTORY>/${config_dir}${ARG_NAME}_plugin.dll)
    endif()
    
    target_compile_definitions(${ARG_NAME} PRIVATE
        HARDLY_PLUGIN # this will affect the macros used for registering mixins - for supporting plugin reloading
    )
    
    mixify_target(${ARG_NAME})
    
    # add the plugin to the list of plugins - so the main executable can depend on them
    list(APPEND PLUGINS ${ARG_NAME})
    set(PLUGINS ${PLUGINS} PARENT_SCOPE) # because we are a function
endfunction()

# should be used on libraries (static or dynamic) which will be linked to other dynamic libraries
function(add_fPIC_to_target lib)
    if(NOT WIN32)
        target_compile_options(${lib} PRIVATE -fPIC)
    endif()
endfunction()







# TODO: TEST THIS! got it from here: https://gist.github.com/Zeex/5291602
# group_target_sources(target) - group target's source files on based on their directory.
function(group_target_sources target)
	get_target_property(sources ${target} SOURCES)
	foreach(file ${sources})
		get_filename_component(path "${file}" ABSOLUTE)
		get_filename_component(path "${path}" PATH)
		if(file MATCHES "${PROJECT_BINARY_DIR}")
			file(RELATIVE_PATH path ${PROJECT_BINARY_DIR} "${path}")
		else()
			file(RELATIVE_PATH path ${PROJECT_SOURCE_DIR} "${path}")
		endif()
		string(REGEX REPLACE "/" "\\\\" win_path "${path}")
		source_group("${win_path}" REGULAR_EXPRESSION "${path}/[^/\\]+\\..*")
	endforeach()
endfunction()










#macro(get_all_interface_link_libraries target res)
#    message(${target})
#    set(${res} "")
#    if(TARGET ${target})
#        get_target_property(libs ${target} INTERFACE_LINK_LIBRARIES)
#        if(NOT "${libs}" STREQUAL "libs-NOTFOUND")
#            foreach(item ${libs})
#                set(temp "")
#                get_all_interface_link_libraries(${item} temp)
#                list(APPEND ${res} ${temp})
#            endforeach()
#        endif()
#    endif()
#    set(${res} ${${res}} PARENT_SCOPE)
#endmacro()
#
# https://stackoverflow.com/questions/32756195/recursive-list-of-link-libraries-in-cmake
#function(get_link_libraries OUTPUT_LIST TARGET)
#    get_target_property(IMPORTED ${TARGET} IMPORTED)
#    list(APPEND VISITED_TARGETS ${TARGET})
#    if (IMPORTED)
#        get_target_property(LIBS ${TARGET} INTERFACE_LINK_LIBRARIES)
#    endif()
#    set(LIB_FILES "")
#    foreach(LIB ${LIBS})
#        if (TARGET ${LIB})
#            list(FIND VISITED_TARGETS ${LIB} VISITED)
#            if (${VISITED} EQUAL -1)
#                get_link_libraries(LINK_LIB_FILES ${LIB})
#                list(APPEND LIB_FILES ${LIB} ${LINK_LIB_FILES})
#            endif()
#        endif()
#    endforeach()
#    set(VISITED_TARGETS ${VISITED_TARGETS} PARENT_SCOPE)
#    set(${OUTPUT_LIST} ${LIB_FILES} PARENT_SCOPE)
#endfunction()