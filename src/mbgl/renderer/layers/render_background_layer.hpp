#pragma once

#include <mbgl/programs/background_program.hpp>
#include <mbgl/renderer/render_layer.hpp>
#include <mbgl/style/layers/background_layer_impl.hpp>
#include <mbgl/style/layers/background_layer_properties.hpp>

#include <optional>
#include <memory>
#include <vector>

namespace mbgl {

namespace gfx {
class Drawable;
using DrawablePtr = std::shared_ptr<Drawable>;
} // namespace gfx

class ChangeRequest;

class RenderBackgroundLayer final : public RenderLayer {
public:
    explicit RenderBackgroundLayer(Immutable<style::BackgroundLayer::Impl>);
    ~RenderBackgroundLayer() override;

    void layerRemoved(UniqueChangeRequestVec&) override;

    /// Generate any changes needed by the layer
    void update(gfx::ShaderRegistry&,
                gfx::Context&,
                const TransformState&,
                const RenderTree&,
                UniqueChangeRequestVec&) override;

private:
    void transition(const TransitionParameters&) override;
    void evaluate(const PropertyEvaluationParameters&) override;
    bool hasTransition() const override;
    bool hasCrossfade() const override;
    std::optional<Color> getSolidBackground() const override;
    void render(PaintParameters&) override;
    void prepare(const LayerPrepareParameters&) override;

    // Paint properties
    style::BackgroundPaintProperties::Unevaluated unevaluated;
    SegmentVector<BackgroundAttributes> segments;

    // Programs
    std::shared_ptr<BackgroundProgram> backgroundProgram;
    std::shared_ptr<BackgroundPatternProgram> backgroundPatternProgram;

    gfx::ShaderProgramBasePtr shader;
};

} // namespace mbgl
