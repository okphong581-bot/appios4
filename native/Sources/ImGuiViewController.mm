#import "ImGuiViewController.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "ImGui/imgui.h"
#import "ImGui/imgui_impl_metal.h"
#import <QuartzCore/QuartzCore.h>

@interface ImGuiViewController () <MTKViewDelegate>
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) BOOL showMenu;
@property (nonatomic, assign) CGRect menuRect;
@end

@implementation ImGuiViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.showMenu = YES;
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
    
    // Setup Metal
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    self.commandQueue = [device newCommandQueue];
    
    self.mtkView = [[MTKView alloc] initWithFrame:self.view.bounds device:device];
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    self.mtkView.backgroundColor = [UIColor clearColor];
    self.mtkView.opaque = NO;
    self.mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.mtkView];
    
    // Setup ImGui
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    
    // Disable ini file saving
    io.IniFilename = NULL;
    
    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    
    // Setup Platform/Renderer backends
    ImGui_ImplMetal_Init(device);
    
    // Set display size initially
    io.DisplaySize = ImVec2(self.view.bounds.size.width, self.view.bounds.size.height);
    
    // Apple UI scaling
    CGFloat scale = [UIScreen mainScreen].scale;
    io.DisplayFramebufferScale = ImVec2(scale, scale);
    
    // Set up standard game hack style font size
    ImFontConfig font_config;
    font_config.SizePixels = 26.0f;
    io.Fonts->AddFontDefault(&font_config);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(self.view.bounds.size.width, self.view.bounds.size.height);
}

// MARK: - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Nothing
}

- (void)drawInMTKView:(MTKView *)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);
    
    CGFloat scale = [UIScreen mainScreen].scale;
    io.DisplayFramebufferScale = ImVec2(scale, scale);
    
    // Setup delta time
    static CFTimeInterval lastTime = 0;
    CFTimeInterval currentTime = CACurrentMediaTime();
    if (lastTime == 0) {
        io.DeltaTime = 1.0f / 60.0f;
    } else {
        io.DeltaTime = currentTime - lastTime;
    }
    lastTime = currentTime;
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil) {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"ImGui Render"];
        
        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();
        
        // --- RENDER MOD MENU ---
        if (self.showMenu) {
            ImGui::SetNextWindowSize(ImVec2(350, 450), ImGuiCond_FirstUseEver);
            bool bShow = self.showMenu;
            ImGui::Begin("HaNhayVIP MOD", &bShow, ImGuiWindowFlags_NoCollapse);
            self.showMenu = bShow;
            
            ImVec2 pos = ImGui::GetWindowPos();
            ImVec2 size = ImGui::GetWindowSize();
            self.menuRect = CGRectMake(pos.x, pos.y, size.x, size.y);
            
            ImGui::Text("Welcome to C++ ImGui Mod Menu!");
            ImGui::Separator();
            
            static bool aimbot = false;
            static bool esp = true;
            static float fov = 90.0f;
            
            ImGui::Checkbox("Aimbot", &aimbot);
            ImGui::Checkbox("ESP", &esp);
            ImGui::SliderFloat("FOV", &fov, 30.0f, 150.0f);
            
            if (ImGui::Button("Close Menu")) {
                self.showMenu = NO;
            }
            
            ImGui::End();
        } else {
            // Draw floating icon when menu is closed
            ImGui::SetNextWindowSize(ImVec2(70, 70), ImGuiCond_Always);
            ImGuiWindowFlags iconFlags = ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoScrollbar;
            ImGui::Begin("Icon", NULL, iconFlags);
            
            ImVec2 pos = ImGui::GetWindowPos();
            ImVec2 size = ImGui::GetWindowSize();
            self.menuRect = CGRectMake(pos.x, pos.y, size.x, size.y);
            
            if (ImGui::Button("MENU", ImVec2(50, 50))) {
                self.showMenu = YES;
            }
            ImGui::End();
        }
        
        // --- END RENDER ---
        ImGui::Render();
        ImDrawData *drawData = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(drawData, commandBuffer, renderEncoder);
        
        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];
        
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    
    [commandBuffer commit];
}

// MARK: - Touch Handling

- (void)updateTouch:(NSSet<UITouch *> *)touches {
    ImGuiIO& io = ImGui::GetIO();
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self.view];
        io.AddMousePosEvent((float)p.x, (float)p.y);
        
        if (touch.phase == UITouchPhaseBegan) {
            io.AddMouseButtonEvent(0, true);
        } else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
            io.AddMouseButtonEvent(0, false);
        }
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self updateTouch:touches];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self updateTouch:touches];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self updateTouch:touches];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self updateTouch:touches];
}

- (BOOL)isPointInsideMenu:(CGPoint)point {
    return CGRectContainsPoint(self.menuRect, point);
}

@end
