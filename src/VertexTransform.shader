Shader "Vertex/Transform"
{
    Properties
    {

        _VertObjectPosition("Object Position Difference", Vector) = (0.0, 0.0, 0.0, 1.0)
        _VertObjectRotation("Object Rotation", Vector) = (0.0, 0.0, 0.0, 1.0)
        _VertObjectScale("Object Scale", Vector) = (1.0, 1.0, 1.0, 1.0)

        _VertWorldPosDiff("World Position Difference", Vector) = (0.0, 0.0, 0.0, 1.0)

        _MainTex("MainTex", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        _ColorMask("ColorMask", 2D) = "black" {}
        _Shadow("Shadow", Range(0, 1)) = 0.4

        _outline_width("outline_width", Float) = 0.2
        _outline_color("outline_color", Color) = (0.5,0.5,0.5,1)
        _outline_tint("outline_tint", Range(0, 1)) = 0.5
        _EmissionMap("Emission Map", 2D) = "white" {}
        [HDR]_EmissionColor("Emission Color", Color) = (0,0,0,1)
        _BumpMap("BumpMap", 2D) = "bump" {}
        _Cutoff("Alpha cutoff", Range(0,1)) = 0.5

        // Blending state
        _Mode ("Mode", Float) = 0.0
        _OutlineMode("Outline Mode", Float) = 0.0
        _SrcBlend ("SRC", Float) = 1.0
        _DstBlend ("DstBlend", Float) = 0.0
        _ZWrite ("ZWrite", Float) = 1.0
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull("Cull", Float) = 0 // Back
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
        }

        Pass
        {

            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]

            CGPROGRAM
            #include "FlatLitToonCore.cginc"
            #include "VertexTransform.cginc"
            #pragma shader_feature NO_OUTLINE TINTED_OUTLINE COLORED_OUTLINE
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma vertex vert_vt
            #pragma geometry geom
            #pragma fragment frag

            #pragma only_renderers d3d11 glcore gles
            #pragma target 4.0

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            float4 frag(VertexOutput i) : COLOR
            {
                float4 objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
                i.normalDir = normalize(i.normalDir);
                float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
                float3 _BumpMap_var = UnpackNormal(tex2D(_BumpMap,TRANSFORM_TEX(i.uv0, _BumpMap)));
                float3 normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform)); // Perturbed normals
                float4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));
                
                float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                float3 lightColor = _LightColor0.rgb;
                UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);

                float4 _EmissionMap_var = tex2D(_EmissionMap,TRANSFORM_TEX(i.uv0, _EmissionMap));
                float3 emissive = (_EmissionMap_var.rgb*_EmissionColor.rgb);
                float4 _ColorMask_var = tex2D(_ColorMask,TRANSFORM_TEX(i.uv0, _ColorMask));
                float4 baseColor = lerp((_MainTex_var.rgba*_Color.rgba),_MainTex_var.rgba,_ColorMask_var.r);
                baseColor *= float4(i.col.rgb, 1);

                #if COLORED_OUTLINE
                if(i.is_outline) 
                {
                    baseColor.rgb = i.col.rgb; 
                }
                #endif

                #if defined(_ALPHATEST_ON)
                clip (baseColor.a - _Cutoff);
                #endif
                
                float3 lightmap = float4(1.0,1.0,1.0,1.0);
                #ifdef LIGHTMAP_ON
                lightmap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1 * unity_LightmapST.xy + unity_LightmapST.zw));
                #endif

                float3 reflectionMap = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, normalize((_WorldSpaceCameraPos - objPos.rgb)), 7), unity_SpecCube0_HDR)* 0.02;

                float grayscalelightcolor = dot(_LightColor0.rgb, grayscale_vector);
                float bottomIndirectLighting = grayscaleSH9(float3(0.0, -1.0, 0.0));
                float topIndirectLighting = grayscaleSH9(float3(0.0, 1.0, 0.0));
                float grayscaleDirectLighting = dot(lightDirection, normalDirection)*grayscalelightcolor*attenuation + grayscaleSH9(normalDirection);

                float lightDifference = topIndirectLighting + grayscalelightcolor - bottomIndirectLighting;
                float remappedLight = (grayscaleDirectLighting - bottomIndirectLighting) / lightDifference;

                float3 indirectLighting = saturate((ShadeSH9(half4(0.0, -1.0, 0.0, 1.0)) + reflectionMap));
                float3 directLighting = saturate((ShadeSH9(half4(0.0, 1.0, 0.0, 1.0)) + reflectionMap + _LightColor0.rgb));
                float3 directContribution = saturate((1.0 - _Shadow) + floor(saturate(remappedLight) * 2.0));
                float3 finalColor = emissive + (baseColor * lerp(indirectLighting, directLighting, directContribution));
                fixed4 finalRGBA = fixed4(finalColor * lightmap, baseColor.a);

                #if !defined(_ALPHABLEND_ON) && !defined(_ALPHAPREMULTIPLY_ON)
                    UNITY_OPAQUE_ALPHA(finalRGBA.a);
                #endif

                UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
                return finalRGBA;
            }
            ENDCG
        }

        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend [_SrcBlend] One

            CGPROGRAM
            #pragma shader_feature NO_OUTLINE TINTED_OUTLINE COLORED_OUTLINE
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #include "FlatLitToonCore.cginc"
            #include "VertexTransform.cginc"
            #pragma vertex vert_vt
            #pragma geometry geom
            #pragma fragment frag

            #pragma only_renderers d3d11 glcore gles
            #pragma target 4.0

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            float4 frag(VertexOutput i) : COLOR
            {
                float4 objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
                i.normalDir = normalize(i.normalDir);
                float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
                float3 _BumpMap_var = UnpackNormal(tex2D(_BumpMap,TRANSFORM_TEX(i.uv0, _BumpMap)));
                float3 normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform)); // Perturbed normals
                float4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));

                float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                float3 lightColor = _LightColor0.rgb;
                UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);
    
                float4 _ColorMask_var = tex2D(_ColorMask,TRANSFORM_TEX(i.uv0, _ColorMask));
                float4 baseColor = lerp((_MainTex_var.rgba*_Color.rgba),_MainTex_var.rgba,_ColorMask_var.r);
                baseColor *= float4(i.col.rgb, 1);

                #if COLORED_OUTLINE
                if(i.is_outline) {
                    baseColor.rgb = i.col.rgb;
                }
                #endif

                #if defined(_ALPHATEST_ON)
                clip (baseColor.a - _Cutoff);
                #endif

                float lightContribution = dot(normalize(_WorldSpaceLightPos0.xyz - i.posWorld.xyz),normalDirection)*attenuation;
                float3 directContribution = floor(saturate(lightContribution) * 2.0);
                float3 finalColor = baseColor * lerp(0, _LightColor0.rgb, saturate(directContribution + ((1 - _Shadow) * attenuation)));
                fixed4 finalRGBA = fixed4(finalColor,1) * i.col;

                #if !defined(_ALPHABLEND_ON) && !defined(_ALPHAPREMULTIPLY_ON)
                    UNITY_OPAQUE_ALPHA(finalRGBA.a);
                #endif

                UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
                return finalRGBA;
            }
            ENDCG
        }

        Pass
        {
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"

            #include "quaternion.cginc"

            float4 _VertObjectScale;
            float4 _VertObjectPosition;
            float4 _VertObjectRotation;

            float4 _VertWorldPosDiff;

            struct v2f
            {
                V2F_SHADOW_CASTER;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert( appdata_base v )
            {
                float4 pos = transform(v.vertex, _VertObjectPosition, _VertObjectRotation, _VertObjectScale);
                float4 worldPos = mul(unity_ObjectToWorld, pos);
                worldPos = float4(worldPos.xyz + (_VertWorldPosDiff.xyz * _VertWorldPosDiff.w), worldPos.w);
                float4 resultPos = mul(unity_WorldToObject, worldPos);

                v.vertex.xyz = resultPos.xyz;

                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag( v2f i ) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }

            ENDCG
        }
    }
    FallBack "Diffuse"
    CustomEditor "VertexTransformShaders.CubedParadoxFlatLitToonInspector"
}