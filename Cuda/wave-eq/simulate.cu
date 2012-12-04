/*
 * simulate.c
 *
 * Implement your (parallel) simulation here!
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <string.h>

#include "simulate.h"

#include <iostream>

using namespace std;

/* Utility function, use to do error checking.

   Use this function like this:

   checkCudaCall(cudaMalloc((void **) &deviceRGB, imgS * sizeof(color_t)));

   And to check the result of a kernel invocation:

   checkCudaCall(cudaGetLastError());
*/
static void checkCudaCall(cudaError_t result) {
    if (result != cudaSuccess) {
        cerr << "cuda error: " << cudaGetErrorString(result) << endl;
        exit(1);
    }
}

// The kernel that simulates an iteration of the wave equation on the GPU
__global__ void simulationKernel(int stepsize, int max,
                                 double *old,
                                 double *current,
                                 double *next)
{
    // determine the boundaries for this particular block
    int i_min = 1 + blockIdx.x * stepsize;
    int i_max = i_min + stepsize;

    /* make sure that i_max doesn't get too large
     * TODO: handle the intervals more neatly. */
    i_max = (i_max > max ? max : i_max);

    // the main simulation loop
    for (int i = i_min; i < i_max; ++i) {
        /* simple implementation of the following wave-equation:
         * A(i, t+1) = 2 * A(i, t) - A(i, t-1) +
         * c * ( A(i-1, t) - (2 * A(i, t) - A(i+1, t)))
         */
        next[i] = 2 * current[i] - old[i] + C * (current[i-1] - (2 * current[i] - current[i + 1]));
    }
}

/*
 * Executes the entire simulation.
 *
 * Implement your code here.
 *
 * i_max: how many data points are on a single wave
 * t_max: how many iterations the simulation should run
 * num_threads: how many threads to use (excluding the main threads)
 * old_array: array of size i_max filled with data for t-1
 * current_array: array of size i_max filled with data for t
 * next_array: array of size i_max. You should fill this with t+1
 */
double *simulate(const int i_max, const int t_max, const int num_threads,
                 double *old_array, double *current_array, double *next_array)
{
    int stepsize = ((i_max - 2) / num_threads) + 1;

    // allocate the vectors on the GPU
    float* d_old = NULL;
    checkCudaCall(cudaMalloc((void **) &d_old, i_max * sizeof(double)));
    if (d_old == NULL) {
        cout << "could not allocate memory!" << endl;
        return;
    }

    double* d_current = NULL;
    checkCudaCall(cudaMalloc((void **) &d_current, i_max * sizeof(double)));
    if (d_current == NULL) {
        checkCudaCall(cudaFree(deviceA));
        cout << "could not allocate memory!" << endl;
        return;
    }

    double* d_next = NULL;
    checkCudaCall(cudaMalloc((void **) &d_next, i_max * sizeof(double)));
    if (d_next == NULL) {
        checkCudaCall(cudaFree(deviceA));
        checkCudaCall(cudaFree(deviceB));
        cout << "could not allocate memory!" << endl;
        return;
    }

    // copy the data to the GPU
    checkCudaCall(cudaMemcpy(d_old, old_array, i_max*sizeof(double), cudaMemcpyHostToDevice));
    checkCudaCall(cudaMemcpy(d_current, current_array, i_max*sizeof(double), cudaMemcpyHostToDevice));
    checkCudaCall(cudaMemcpy(d_next, next_array, i_max*sizeof(double), cudaMemcpyHostToDevice));

    // the main loop
    for (int t = 0; t < t_max; ++t) {
        add <<< num_threads, 1 >>> (stepsize, max, old_dev, curr_dev, next_dev);

        // swap the arrays around
        double *temp_old = d_old;
        d_old = d_current;
        d_current = d_next;
        d_next = temp_old;
    }

    // copy the data back to the main program
    checkCudaCall(cudaMemcpy(old_array, d_old, i_max*sizeof(double), cudaMemcpyDeviceToHost));
    checkCudaCall(cudaMemcpy(current_array, d_current, i_max*sizeof(double), cudaMemcpyDeviceToHost));
    checkCudaCall(cudaMemcpy(next_array, d_next, i_max*sizeof(double), cudaMemcpyDeviceToHost));

    return current_array;
}