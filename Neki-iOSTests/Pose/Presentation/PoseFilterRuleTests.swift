//
//  PoseFilterRuleTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/11/26.
//

import Testing
@testable import Neki_iOS

struct PoseFilterRuleTests {
    @Test("관계 태그를 고르면 인원수가 2인으로 선택된다", arguments: PoseRelation.allCases)
    func toggleRelation_selectsDuo(relation: PoseRelation) {
        var state = PoseFeature.State()

        state.toggleRelationFilter(relation)

        #expect(state.selectedCountFilterOption == .duo)
        #expect(state.selectedRelationFilterOption == relation)
    }

    @Test("3인을 고른 상태에서 커플을 고르면 2인으로 바뀐다")
    func toggleRelation_whileTrio_switchesToDuo() {
        var state = PoseFeature.State()
        state.togglePeopleCountFilter(.trio)

        state.toggleRelationFilter(.couple)

        #expect(state.selectedCountFilterOption == .duo)
        #expect(state.selectedRelationFilterOption == .couple)
    }

    @Test("같은 관계 태그를 다시 누르면 관계만 해제되고 2인은 남는다")
    func toggleSameRelation_clearsRelationOnly() {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.friend)

        state.toggleRelationFilter(.friend)

        #expect(state.selectedRelationFilterOption == nil)
        #expect(state.selectedCountFilterOption == .duo)
    }

    @Test("다른 관계 태그를 고르면 관계만 바뀌고 2인은 남는다")
    func toggleOtherRelation_replacesRelationOnly() {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.friend)

        state.toggleRelationFilter(.crush)

        #expect(state.selectedRelationFilterOption == .crush)
        #expect(state.selectedCountFilterOption == .duo)
    }

    @Test("관계를 고른 상태에서 2인이 아닌 인원수를 고르면 관계가 해제된다", arguments: [PeopleCountOption.solo, .trio, .quartet])
    func selectOtherPeopleCount_whileRelation_clearsRelation(option: PeopleCountOption) {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.couple)

        state.togglePeopleCountFilter(option)

        #expect(state.selectedCountFilterOption == option)
        #expect(state.selectedRelationFilterOption == nil)
    }

    @Test("관계를 고른 상태에서 2인을 다시 눌러 해제하면 관계도 해제된다")
    func deselectDuo_whileRelation_clearsRelation() {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.couple)

        state.togglePeopleCountFilter(.duo)

        #expect(state.selectedCountFilterOption == nil)
        #expect(state.selectedRelationFilterOption == nil)
    }

    @Test("북마크를 켠 상태에서 관계 태그를 고르면 북마크가 꺼지고 2인과 관계가 선택된다")
    func toggleRelation_whileBookmark_turnsBookmarkOff() {
        var state = PoseFeature.State()
        state.toggleBookmarkFilter()

        state.toggleRelationFilter(.friend)

        #expect(state.isSelectedScrap == false)
        #expect(state.selectedCountFilterOption == .duo)
        #expect(state.selectedRelationFilterOption == .friend)
    }

    @Test("관계를 고른 상태에서 북마크를 누르면 인원수와 관계가 비워진다")
    func toggleBookmark_whileRelation_clearsPeopleCountAndRelation() {
        var state = PoseFeature.State()
        state.toggleRelationFilter(.friend)

        state.toggleBookmarkFilter()

        #expect(state.isSelectedScrap)
        #expect(state.selectedCountFilterOption == nil)
        #expect(state.selectedRelationFilterOption == nil)
    }

    @Test("북마크를 켠 상태에서 인원수를 고르면 북마크가 꺼지고, 같은 인원수를 다시 고르면 해제된다")
    func togglePeopleCount_whileBookmark_turnsBookmarkOffThenDeselects() {
        var state = PoseFeature.State()
        state.toggleBookmarkFilter()

        state.togglePeopleCountFilter(.trio)

        #expect(state.isSelectedScrap == false)
        #expect(state.selectedCountFilterOption == .trio)

        state.togglePeopleCountFilter(.trio)

        #expect(state.selectedCountFilterOption == nil)
    }

    @Test("2인을 고른 상태에서 관계 태그만 고르거나 바꾸거나 해제하면 목록 조건은 그대로다")
    func relationOnlyChanges_keepListCondition() {
        var state = PoseFeature.State()
        state.togglePeopleCountFilter(.duo)
        let condition = state.listCondition

        state.toggleRelationFilter(.friend)
        #expect(state.listCondition == condition)

        state.toggleRelationFilter(.couple)
        #expect(state.listCondition == condition)

        state.toggleRelationFilter(.couple)
        #expect(state.listCondition == condition)
    }

    @Test("받은 포즈가 없고 끝까지 불러오지 않았으면 포즈 개수를 숨긴다")
    func displayedPoseCount_whileFirstPageLoading_isNil() {
        var state = PoseFeature.State()
        state.isGeneralLoading = true

        #expect(state.displayedPoseCount == nil)
    }

    @Test("끝까지 불러온 목록이 비어 있으면 포즈 개수를 0개로 보여 준다")
    func displayedPoseCount_whenLastPageIsEmpty_isZero() {
        var state = PoseFeature.State()
        state.isLastGeneralPage = true

        #expect(state.displayedPoseCount == 0)
    }
}
