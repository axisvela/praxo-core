#define CL_TARGET_OPENCL_VERSION 300
#include <CL/cl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "praxo.h"

static const char *kernel_source =
    "__kernel void add_one(__global int *values) {\n"
    "    int index = get_global_id(0);\n"
    "    values[index] = values[index] + 1;\n"
    "}\n";

static int fail(const char *message) {
    fprintf(stderr, "opencl-sample: %s\n", message);
    return 1;
}

static int check(cl_int status, const char *operation) {
    if (status != CL_SUCCESS) {
        fprintf(stderr, "opencl-sample: %s failed (%d)\n", operation, status);
        return 0;
    }
    return 1;
}

int main(void) {
    PxArena arena;
    px_arena_init(&arena);
    PxValue *call = px_parse(&arena, "{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}");
    const char *name = call == NULL ? NULL : px_get_str(call, "name");
    if (name == NULL) {
        px_arena_free(&arena);
        return fail("cannot parse PRAXO JSON");
    }

    cl_platform_id platform = NULL;
    cl_uint platform_count = 0;
    if (!check(clGetPlatformIDs(1, &platform, &platform_count), "clGetPlatformIDs")
        || platform_count == 0) {
        px_arena_free(&arena);
        return fail("no OpenCL platform");
    }

    cl_device_id device = NULL;
    if (!check(clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, 1, &device, NULL), "clGetDeviceIDs")) {
        px_arena_free(&arena);
        return 1;
    }

    cl_int status = CL_SUCCESS;
    cl_context context = clCreateContext(NULL, 1, &device, NULL, NULL, &status);
    if (!check(status, "clCreateContext")) {
        px_arena_free(&arena);
        return 1;
    }
    cl_command_queue queue = clCreateCommandQueueWithProperties(context, device, NULL, &status);
    if (!check(status, "clCreateCommandQueueWithProperties")) {
        clReleaseContext(context);
        px_arena_free(&arena);
        return 1;
    }

    cl_program program = clCreateProgramWithSource(context, 1, &kernel_source, NULL, &status);
    if (!check(status, "clCreateProgramWithSource")) {
        clReleaseCommandQueue(queue);
        clReleaseContext(context);
        px_arena_free(&arena);
        return 1;
    }
    status = clBuildProgram(program, 1, &device, NULL, NULL, NULL);
    if (status != CL_SUCCESS) {
        size_t log_size = 0;
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, 0, NULL, &log_size);
        char *log = log_size == 0 ? NULL : (char *)malloc(log_size + 1);
        if (log != NULL) {
            clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, log_size, log, NULL);
            log[log_size] = '\0';
            fprintf(stderr, "%s\n", log);
            free(log);
        }
        clReleaseProgram(program);
        clReleaseCommandQueue(queue);
        clReleaseContext(context);
        px_arena_free(&arena);
        return fail("kernel build failed");
    }

    cl_kernel kernel = clCreateKernel(program, "add_one", &status);
    if (!check(status, "clCreateKernel")) {
        clReleaseProgram(program);
        clReleaseCommandQueue(queue);
        clReleaseContext(context);
        px_arena_free(&arena);
        return 1;
    }

    int values[4] = {1, 2, 3, 4};
    cl_mem buffer = clCreateBuffer(
        context,
        CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR,
        sizeof(values),
        values,
        &status
    );
    if (!check(status, "clCreateBuffer")) {
        clReleaseKernel(kernel);
        clReleaseProgram(program);
        clReleaseCommandQueue(queue);
        clReleaseContext(context);
        px_arena_free(&arena);
        return 1;
    }
    if (!check(clSetKernelArg(kernel, 0, sizeof(buffer), &buffer), "clSetKernelArg")) {
        clReleaseMemObject(buffer);
        clReleaseKernel(kernel);
        clReleaseProgram(program);
        clReleaseCommandQueue(queue);
        clReleaseContext(context);
        px_arena_free(&arena);
        return 1;
    }

    size_t global_size = 4;
    if (!check(
            clEnqueueNDRangeKernel(queue, kernel, 1, NULL, &global_size, NULL, 0, NULL, NULL),
            "clEnqueueNDRangeKernel"
        )) {
        clReleaseMemObject(buffer);
        clReleaseKernel(kernel);
        clReleaseProgram(program);
        clReleaseCommandQueue(queue);
        clReleaseContext(context);
        px_arena_free(&arena);
        return 1;
    }

    int output[4] = {0, 0, 0, 0};
    if (!check(
            clEnqueueReadBuffer(queue, buffer, CL_TRUE, 0, sizeof(output), output, 0, NULL, NULL),
            "clEnqueueReadBuffer"
        )) {
        clReleaseMemObject(buffer);
        clReleaseKernel(kernel);
        clReleaseProgram(program);
        clReleaseCommandQueue(queue);
        clReleaseContext(context);
        px_arena_free(&arena);
        return 1;
    }

    clReleaseMemObject(buffer);
    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseCommandQueue(queue);
    clReleaseContext(context);

    for (int index = 0; index < 4; index++) {
        if (output[index] != values[index] + 1) {
            px_arena_free(&arena);
            return fail("kernel result mismatch");
        }
    }

    printf("OpenCL sample passed: %s\n", name);
    px_arena_free(&arena);
    return 0;
}
