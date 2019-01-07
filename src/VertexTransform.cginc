#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"

#include "quaternion.cginc"

float4 _VertObjectPosition;
float4 _VertObjectRotation;
float4 _VertObjectScale;

float4 _VertWorldPosDiff;

v2g vert_vt(appdata_full v) {
    v2g o;
    o.uv0 = v.texcoord;
    o.uv1 = v.texcoord1;
    o.tangent = v.tangent;
    o.normal = v.normal;

    {
        float3 objNormal = rotate_with_quaternion(v.normal, _VertObjectRotation.xyz);
        float3 worldNormal = UnityObjectToWorldNormal(objNormal);
        o.normalDir = normalize(worldNormal);
    }

    {
        float3 objTangent = rotate_with_quaternion(v.tangent.xyz, _VertObjectRotation.xyz);
        float3 worldTangent = mul(unity_ObjectToWorld, float4(objTangent, 0.0)).xyz;
        o.tangentDir = normalize(worldTangent);
    }

    o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);

    float4 pos = transform(v.vertex, _VertObjectPosition, _VertObjectRotation, _VertObjectScale);

    float4 worldPos = mul(unity_ObjectToWorld, pos);
    worldPos = float4(worldPos.xyz + (_VertWorldPosDiff.xyz * _VertWorldPosDiff.w), worldPos.w);

    float4 resultPos = mul(unity_WorldToObject, worldPos);

    o.posWorld = worldPos;
    o.vertex = resultPos;
    o.pos = UnityObjectToClipPos(resultPos);

    float3 lightColor = _LightColor0.rgb;
    TRANSFER_SHADOW(o);
    UNITY_TRANSFER_FOG(o, o.pos);
    return o;
}