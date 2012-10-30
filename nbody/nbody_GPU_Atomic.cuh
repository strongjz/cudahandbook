/*
 *
 * nbody_GPU_Atomic.h
 *
 * CUDA implementation of the O(N^2) N-body calculation.
 *
 * Copyright (c) 2011-2012, Archaea Software, LLC.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions 
 * are met: 
 *
 * 1. Redistributions of source code must retain the above copyright 
 *    notice, this list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright 
 *    notice, this list of conditions and the following disclaimer in 
 *    the documentation and/or other materials provided with the 
 *    distribution. 
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
 * COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 *
 */

template<typename T>
__global__ void
ComputeNBodyGravitation_Atomic( T *force, T *posMass, size_t N, T softeningSquared )
{
    for ( int i = blockIdx.x*blockDim.x + threadIdx.x;
              i < N;
              i += blockDim.x*gridDim.x )
    {
        float4 me = ((float4 *) posMass)[i];
        T acc[3] = {0.0f, 0.0f, 0.0f};
        T myX = me.x;
        T myY = me.y;
        T myZ = me.z;
        for ( int j = 0; j < N; j++ ) {
            float4 body = ((float4 *) posMass)[j];

            T ax, ay, az;
            bodyBodyInteraction( ax, ay, az, myX, myY, myZ, body.x, body.y, body.z, body.w, softeningSquared);

#if defined(__CUDA_ARCH__) && __CUDA_ARCH__ >= 300
            atomicAdd( &force[3*i+0], ax );
            atomicAdd( &force[3*i+1], ay );
            atomicAdd( &force[3*i+2], az );
#endif


#if 0
            acc[0] += ax; acc[1] += ay; acc[2] += az;
#if defined(__CUDA_ARCH__) && __CUDA_ARCH__ >= 300
            int complement = N-j-1;
            atomicAdd( &force[3*complement+0], ax );
            atomicAdd( &force[3*complement+1], ay );
            atomicAdd( &force[3*complement+2], az );
#endif
#endif

        }
#if 0
#if defined(__CUDA_ARCH__) && __CUDA_ARCH__ >= 300
        atomicAdd( &force[3*i+0], acc[0] );
        atomicAdd( &force[3*i+1], acc[1] );
        atomicAdd( &force[3*i+2], acc[2] );
#endif
#endif
    }
}

float
ComputeGravitation_GPU_Atomic(
    float *force, 
    float *posMass,
    float softeningSquared,
    size_t N
)
{
    cudaError_t status;
    cudaEvent_t evStart = 0, evStop = 0;
    float ms = 0.0;
    CUDART_CHECK( cudaEventCreate( &evStart ) );
    CUDART_CHECK( cudaEventCreate( &evStop ) );
    CUDART_CHECK( cudaEventRecord( evStart, NULL ) );
    CUDART_CHECK( cudaMemset( force, 0, 3*N*sizeof(float) ) );
    ComputeNBodyGravitation_Atomic<float> <<<300,256>>>( force, posMass, N, softeningSquared );
    CUDART_CHECK( cudaEventRecord( evStop, NULL ) );
    CUDART_CHECK( cudaDeviceSynchronize() );
    CUDART_CHECK( cudaEventElapsedTime( &ms, evStart, evStop ) );
Error:
    CUDART_CHECK( cudaEventDestroy( evStop ) );
    CUDART_CHECK( cudaEventDestroy( evStart ) );
    return ms;
}
