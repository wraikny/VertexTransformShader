#ifndef __wraikny_quaternion_include__
#define __wraikny_quaternion_include__

float4 quaternion_conjugate(float4 v) {
    return float4(
        v.x, -v.yzw
    );
}

float4 quaternion_mul(float4 v1, float4 v2) {
    float4 result1 = (v1.x * v2 + v1 * v2.x);
    
    float4 result2 = float4(
        -dot(v1.yzw, v2.yzw),
        cross(v1.yzw, v2.yzw)
    );

    return float4(result1 + result2);
}

// angle : radians
float4 get_quaternion_from_angle(float3 axis, float angle) {
    return float4(
        cos(angle / 2.0),
        normalize(axis) * sin(angle / 2.0)
    );
}

float4 quaternion_from_vector(float3 inVec) {
    return float4(0.0, inVec);
}

#ifndef PI
#define PI 3.14159265
#endif

float degree_to_radius(float degree) {
    return(
        degree / 180.0 * PI
    );
}

float3 rotate_with_quaternion(float3 inVec, float3 rotation) {
    if(
        (rotation.x % 360.0 == 0.0) &&
        (rotation.x % 360.0 == 0.0) &&
        (rotation.x % 360.0 == 0.0)
    ) {
        // return inVec;
    }

    float4 qx = get_quaternion_from_angle(float3(1, 0, 0), degree_to_radius(rotation.x));
    float4 qy = get_quaternion_from_angle(float3(0, 1, 0), degree_to_radius(rotation.y));
    float4 qz = get_quaternion_from_angle(float3(0, 0, 1), degree_to_radius(rotation.z));
    
    #define MUL3(A, B, C) quaternion_mul(quaternion_mul((A), (B)), (C))
    float4 quaternion = normalize(MUL3(qx, qy, qz));
    float4 conjugate = quaternion_conjugate(quaternion);

    float4 inVecQ = quaternion_from_vector(inVec);

    float3 rotated = (
        MUL3(quaternion, inVecQ, conjugate)
    ).yzw;

    return rotated;
}

float4 transform(float4 input, float4 pos, float4 rotation, float4 scale) {
    return float4(
        rotate_with_quaternion(input.xyz, rotation.xyz * rotation.w)
        * (scale.xyz * scale.w)
        + (pos.xyz * pos.w)
        ,
        input.w
    );
}

#endif // __wraikny_quaternion_include__