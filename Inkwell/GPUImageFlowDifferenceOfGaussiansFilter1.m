//
//  GPUImageFlowDifferenceOfGaussiansFilter1.m
//  Inkwell
//
//  Created by John Hurliman on 2/4/16.
//  Copyright © 2016 John Hurliman. All rights reserved.
//

#import "GPUImageFlowDifferenceOfGaussiansFilter1.h"

@implementation GPUImageFlowDifferenceOfGaussiansFilter1 {
    GLuint _imageSizeUniform, _sigmaMUniform, _phiUniform, _epsilonUniform;
    CGSize _imageSize;
    CGFloat _sigmaM, _phi, _epsilon;
}

NSString *const kGPUImageFlowDifferenceOfGaussians1FragmentShader = SHADER_STRING(
precision highp float;

varying vec2 textureCoordinate;
varying vec2 textureCoordinate2;

uniform sampler2D inputImageTexture;  // Source Image
uniform sampler2D inputImageTexture2; // Edge Tangent Flow
uniform vec2 imageSize;
uniform float sigma_m;
uniform float phi;
uniform float epsilon;

struct step_t {
    vec2 p;   // Point
    vec2 t;   // Tangent
    float w;
    float dw;
};

float tanh(float val)
{
    float tmp = exp(val);
    float oo_tmp = 1.0 / tmp;
    return (tmp - oo_tmp) / (tmp + oo_tmp);
}

void step(inout step_t s)
{
    vec2 t = texture2D(inputImageTexture2, s.p).xy;
    if (dot(t, s.t) < 0.0) t = -t;
    s.t = t;
    
    s.dw = (abs(t.x) > abs(t.y)) ?
        abs((fract(s.p.x) - 0.5 - sign(t.x)) / t.x) :
        abs((fract(s.p.y) - 0.5 - sign(t.y)) / t.y);
    
    s.p += t * s.dw / imageSize;
    s.w += s.dw;
}

void main()
{
    vec2 uv = textureCoordinate;
    float twoSigmaMSquared = 2.0 * sigma_m * sigma_m;
    float halfWidth = 2.0 * sigma_m;
    
    float H = texture2D(inputImageTexture, uv).x;
    float w = 1.0;
    
    step_t a;
    a.p = uv;
    a.t = texture2D(inputImageTexture2, uv).xy / imageSize;
    a.w = 0.0;
    
    step_t b;
    b.p = uv;
    b.t = -a.t;
    b.w = 0.0;
    
    while (a.w < halfWidth) {
        step(a);
        float k = a.dw * exp(-a.w * a.w / twoSigmaMSquared);
        H += k * texture2D(inputImageTexture, a.p).x;
        w += k;
    }
    
    while (b.w < halfWidth) {
        step(b);
        float k = b.dw * exp(-b.w * b.w / twoSigmaMSquared);
        H += k * texture2D(inputImageTexture, b.p).x;
        w += k;
    }
    
    H /= w;
    
    H *= 100.0;
    float edge = (H > epsilon) ? 1.0 : 1.0 + tanh(phi * (H - epsilon));
    //float edge = (H > 0.0) ? 1.0 : 2.0 * smoothstep(-2.0, 2.0, phi * H);
    gl_FragColor = vec4(vec3(edge), 1.0);
}
);

- (id)init
{
    if (self = [super initWithFragmentShaderFromString:kGPUImageFlowDifferenceOfGaussians1FragmentShader]) {
        _imageSizeUniform = [filterProgram uniformIndex:@"imageSize"];
        _sigmaMUniform = [filterProgram uniformIndex:@"sigma_m"];
        _phiUniform = [filterProgram uniformIndex:@"phi"];
        _epsilonUniform = [filterProgram uniformIndex:@"epsilon"];
        
        self.imageSize = CGSizeMake(640.0, 800.0);
        self.sigmaM = 3.0;
        self.phi = 2.0;
        self.epsilon = 0.0;
    }
    
    return self;
}

- (void)setImageSize:(CGSize)imageSize
{
    _imageSize = imageSize;
    [self setSize:imageSize forUniform:_imageSizeUniform program:filterProgram];
}

- (void)setSigmaM:(CGFloat)sigmaM
{
    _sigmaM = sigmaM;
    [self setFloat:sigmaM forUniform:_sigmaMUniform program:filterProgram];
}

- (void)setPhi:(CGFloat)phi
{
    _phi = phi;
    [self setFloat:phi forUniform:_phiUniform program:filterProgram];
}

- (void)setEpsilon:(CGFloat)epsilon
{
    _epsilon = epsilon;
    [self setFloat:epsilon forUniform:_epsilonUniform program:filterProgram];
}

@end
